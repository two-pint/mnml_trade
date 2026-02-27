# High-Level Design: Stock Analysis Platform (MNML Trade)

**Document Version**: 1.0  
**Based on PRD**: mnml_prd.md v3.0  
**Last Updated**: February 24, 2026

---

## 1. Introduction

This High-Level Design (HLD) describes the technical architecture of the Stock Analysis Platform. It translates product requirements from the PRD into a concrete system design: components, boundaries, data flows, integrations, and deployment. The document is intended for engineers implementing the system and for stakeholders reviewing technical approach.

### 1.1 Scope

- **In scope**: Web app (Next.js), mobile app (React Native/Expo), Phoenix API, shared packages, external API integrations, caching, auth, paper trading, and institutional data pipelines.
- **Out of scope**: Detailed class-level design (covered in implementation), third-party API internals, and App Store/Play Store submission processes.

### 1.2 Design Principles

- **Single API**: One Phoenix backend serves web and mobile; no backend duplication.
- **Share maximally**: Types, API client, UI primitives, and Tailwind config shared across web and mobile via monorepo.
- **Cache aggressively**: Minimize cost and latency for external APIs; cache tiers by data volatility.
- **Fail gracefully**: Stale cache, partial responses, and clear “as of” timestamps over hard failures.

### 1.3 Logical Milestones (Overview)

The HLD is implemented in six logical milestones. Each milestone is a shippable slice of the system with clear scope and dependencies.

```
M1 Foundation ──► M2 Stock Analysis Core ──► M3 Full Analysis & Institutional
        │                    │                            │
        │                    └────────────┬───────────────┘
        │                                 ▼
        │                    M4 Paper Trading ◄─────────────┐
        │                                 │                 │
        └────────────────────────────────┼─────────────────┘
                                         ▼
                              M5 Engagement & Sharing
                                         │
                                         ▼
                              M6 Polish & Scale
```

| Milestone | Focus | PRD Phase |
|-----------|--------|-----------|
| **M1** | Monorepo, auth, API skeleton, deploy pipeline | Phase 1 (Week 1) |
| **M2** | Technical analysis, stock overview, web + mobile shells | Phase 1 (Weeks 2–5) |
| **M3** | Fundamental + Sentiment + Institutional, recommendation, all 4 tabs | Phase 2 (Weeks 6–8) |
| **M4** | Paper trading (backend + web + mobile) | Phase 2 (Weeks 7–10) |
| **M5** | Watchlist, history, share links, push, Oban refresh | Phase 3 (Weeks 11–13) |
| **M6** | Store submission, Redis optional, performance, advanced features | Phase 4 (Weeks 14–16) |

Detailed scope, deliverables, and HLD section mapping for each milestone are in **Section 12 (Logical Milestones)**.

---

## 2. System Context

### 2.1 Context Diagram

```
                                    ┌─────────────────────────────────────┐
                                    │         External Data Providers      │
                                    │  Alpha Vantage │ FMP │ Finnhub       │
                                    │  Reddit/PRAW   │ Unusual Whales      │
                                    │  OpenAI/Claude (sentiment)           │
                                    └───────────────────┬─────────────────┘
                                                        │ HTTPS / REST
                                                        ▼
┌──────────────┐     HTTPS + JWT      ┌─────────────────────────────────────────────────────────┐
│   Web User   │◄───────────────────►│                 Phoenix API (Fly.io)                     │
│  (Browser)   │                     │  REST API │ WebSockets │ Oban │ ETS/Redis Cache        │
└──────────────┘                     └──────────────────────────┬──────────────────────────────┘
                                                                 │
┌──────────────┐     HTTPS + JWT      ┌──────────────────────────┴──────────────────────────────┐
│ Mobile User  │◄───────────────────►│                    PostgreSQL (Fly.io)                   │
│ (iOS/Android)│                     └─────────────────────────────────────────────────────────┘
└──────────────┘

                                    ┌─────────────────────────────────────┐
                                    │     Deployment / Build / Ops         │
                                    │  Vercel (web) │ EAS (mobile builds)  │
                                    │  Fly.io (API + DB) │ GitHub Actions  │
                                    └─────────────────────────────────────┘
```

### 2.2 Actors

| Actor | Interaction |
|-------|-------------|
| **Web User** | Uses Next.js app in browser; auth via JWT; reads analysis, watchlist, paper trading. |
| **Mobile User** | Uses React Native app (Expo); same API and JWT; push notifications, biometric auth. |
| **External APIs** | Phoenix calls them server-side only; keys never exposed to clients. |
| **Unauthenticated Visitor** | Can view shared analysis/portfolio links (read-only public endpoints). |

### 2.3 System Boundaries

- **Inside**: Monorepo (apps + packages), Phoenix API, PostgreSQL, in-process/Redis cache, Oban jobs, Expo push.
- **Outside**: Alpha Vantage, FMP, Finnhub, Reddit (PRAW), Unusual Whales, OpenAI/Claude, Vercel, Fly.io, EAS, App Store/Play Store.

---

## 3. Architecture Overview

### 3.1 Logical Architecture (Three-Tier + Monorepo)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           PRESENTATION TIER                                      │
│  ┌─────────────────────────────┐    ┌─────────────────────────────┐            │
│  │  Next.js Web (apps/web)      │    │  React Native (apps/mobile)  │            │
│  │  • App Router, RSC, React    │    │  • Expo, Expo Router         │            │
│  │  • Tailwind, Shadcn/ui       │    │  • NativeWind, shared UI     │            │
│  │  • React Query, Zustand      │    │  • React Query, Zustand      │            │
│  └──────────────┬──────────────┘    └──────────────┬──────────────┘            │
│                 │                                   │                            │
│                 └───────────────┬───────────────────┘                            │
│                                 │                                                 │
│  ┌──────────────────────────────▼──────────────────────────────────────────────┐ │
│  │  SHARED PACKAGES (packages/*)                                               │ │
│  │  ui │ api-client │ types │ tailwind-config │ typescript-config │ utils      │ │
│  └──────────────────────────────┬──────────────────────────────────────────────┘ │
└─────────────────────────────────┼─────────────────────────────────────────────────┘
                                  │ HTTPS REST + WebSocket, JWT
┌─────────────────────────────────▼─────────────────────────────────────────────────┐
│                           APPLICATION TIER                                        │
│  ┌─────────────────────────────────────────────────────────────────────────────┐  │
│  │  Phoenix API (apps/api)                                                     │  │
│  │  • HTTP API (JSON), Phoenix Channels (WebSocket)                             │  │
│  │  • Guardian JWT, CORS, rate limiting                                          │  │
│  │  • Contexts: Accounts, Stocks, Analysis, Sentiment, InstitutionalActivity,   │  │
│  │              Watchlist, PaperTrading                                          │  │
│  │  • ETS/Redis cache layer, Oban workers                                        │  │
│  └─────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────┬─────────────────────────────────────────────────┘
                                  │ Ecto, SQL
┌─────────────────────────────────▼─────────────────────────────────────────────────┐
│                           DATA TIER                                               │
│  PostgreSQL (users, watchlists, history, paper portfolios, transactions, cache)   │
│  ETS / Redis (API response cache, session-like data)                               │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Deployment View

```
                         ┌─────────────────────────────────────────┐
                         │            Vercel Edge / Serverless     │
                         │  Next.js (apps/web)                     │
                         │  • SSR/SSG, API routes if any            │
                         │  • NEXT_PUBLIC_API_URL → Phoenix         │
                         └────────────────────┬────────────────────┘
                                              │
                         ┌────────────────────▼────────────────────┐
                         │            Fly.io                        │
                         │  • Phoenix app (apps/api)                │
                         │  • PostgreSQL (Fly Postgres or attached) │
                         │  • Optional: Redis (Upstash/Redis Cloud) │
                         └────────────────────┬────────────────────┘
                                              │
     ┌────────────────────────────────────────┼────────────────────────────────────────┐
     │                                        │                                        │
     ▼                                        ▼                                        ▼
┌─────────────┐                    ┌─────────────────────┐                  ┌─────────────┐
│ Alpha       │                    │ Unusual Whales      │                  │ FMP,        │
│ Vantage     │                    │ (options, dark pool,│                  │ Finnhub,    │
│             │                    │ congressional, etc.)│                  │ Reddit,     │
└─────────────┘                    └─────────────────────┘                  │ Sentiment   │
                                                                             └─────────────┘

Mobile: EAS Build produces iOS/Android binaries; Expo Updates for OTA. Apps call same Phoenix URL (EXPO_PUBLIC_API_URL).
```

### 3.3 Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Monorepo | Turborepo + PNPM | Single repo for web, mobile, API; shared types and API client; one CI and dependency graph. |
| Web framework | Next.js 14+ (App Router) | SSR/SEO, Vercel fit, React ecosystem, shared with mobile via React. |
| Mobile framework | React Native + Expo | Code share with web, single TS codebase, EAS for builds/OTA. |
| Backend | Elixir Phoenix | Concurrency, reliability, good fit for many external API calls and real-time channels. |
| API surface | Single REST + WebSocket API | One contract for web and mobile; no duplicate business logic. |
| Auth | JWT (Guardian) | Stateless, works for web and mobile; same token format. |
| Cache | ETS first, Redis for multi-node | PRD cost control; Redis when scaling to multiple Phoenix nodes. |
| Jobs | Oban | Phoenix-native, DB-backed, reliable background refresh for cache and notifications. |

---

## 4. Component Design

### 4.1 Monorepo Packages (High-Level)

| Package | Purpose | Consumed By |
|---------|---------|-------------|
| **packages/types** | Shared TypeScript types (Stock, User, Portfolio, API DTOs) | web, mobile, api-client |
| **packages/api-client** | HTTP client for Phoenix API (auth, stocks, portfolio, institutional) | web, mobile |
| **packages/ui** | Shared React components + platform adapters (web/native) | web, mobile |
| **packages/tailwind-config** | Shared Tailwind theme (colors, fonts; bullish/bearish, etc.) | web, mobile |
| **packages/typescript-config** | Base/Next/React Native TS configs | all apps and packages |
| **packages/utils** | Formatters, calculations, Zod validators | web, mobile, api-client |

### 4.2 Web Application (apps/web)

- **Role**: Browser-based UI; SEO and shareable URLs for stock and portfolio views.
- **Routing**: Next.js App Router — `(auth)`, `stocks/[ticker]`, `portfolio`, `watchlist`, etc. Tab state for stock page in URL (`?tab=technical|fundamental|emotional|institutional`).
- **Data**: Server Components for initial load and SEO; React Query for client-side refetch, cache, and mutations (watchlist, paper trading).
- **State**: Zustand for UI state (e.g. sidebar); React Query for server state.
- **Key flows**: Login/register → JWT stored (e.g. httpOnly cookie or memory + secure storage); every API call sends `Authorization: Bearer <token>`.

### 4.3 Mobile Application (apps/mobile)

- **Role**: Native iOS/Android experience; same features as web where applicable.
- **Routing**: Expo Router (file-based) — `(tabs)`, `stocks/[ticker]`, `(auth)`.
- **Data**: React Query + same api-client; no RSC; all data via API.
- **Auth**: JWT in Expo SecureStore; biometric unlock (Phase 2+).
- **Platform**: Push (Expo), haptics, share sheet, deep links; charts via Victory Native or similar.

### 4.4 Phoenix API (apps/api) — Contexts

Each context owns a bounded part of the domain and exposes functions used by controllers and Oban workers.

| Context | Responsibility | Key External Dependencies |
|---------|-----------------|---------------------------|
| **Accounts** | Registration, login, JWT issue/refresh, password reset, email verification, profile | Guardian, Bamboo (email) |
| **Stocks** | Search, symbol resolution, “overview” aggregation; orchestration of Analysis + Sentiment + Institutional | Cache, Analysis, Sentiment, InstitutionalActivity |
| **Analysis** | Technical (Alpha Vantage) and fundamental (FMP) data; score computation; recommendation algorithm | Alpha Vantage, FMP, Cache |
| **Sentiment** | Reddit (PRAW or HTTP), news (Finnhub), sentiment engine (LLM or FinBERT); sentiment score | Reddit, Finnhub, OpenAI/Claude, Cache |
| **InstitutionalActivity** | Unusual Whales: options flow, dark pool, congressional, insider, 13F; smart money score; rate limit and queue | Unusual Whales API, Cache, Oban |
| **Watchlist** | CRUD for user watchlist; analysis history (last N viewed) | DB only |
| **PaperTrading** | Portfolios, holdings, market-order execution, transaction history, P&amp;L and performance metrics | Stocks (price), DB |
| **Shares** | Generate and resolve shareable links (analysis or portfolio snapshot); public read-only | DB, optional short-id |

### 4.5 API Layer (Phoenix)

- **Endpoint**: Single `StockAnalysisWeb.Endpoint`; REST under `/api/*`; optional Channel under e.g. `/socket`.
- **Pipeline**: CORS → JSON parser → optional JWT verification (except public routes).
- **Controllers**: Thin; parse params, call context functions, render JSON or 4xx/5xx.
- **Public routes**: `POST /api/auth/login`, `POST /api/auth/register`, `GET /api/shares/:id`, password reset.
- **Protected routes**: All other `/api/*`; require valid JWT.

### 4.6 Cache Layer

- **Location**: ETS (single node) or Redis (multi-node / future).
- **Key shape**: e.g. `{scope}:{ticker}:{data_type}` or `{scope}:institutional:{ticker}:options_flow`.
- **TTL (from PRD)**:
  - Real-time price: 15 s
  - Technical: 1 h
  - Fundamental: 24 h
  - Sentiment: 30 min
  - Unusual Whales options/dark pool: 1 h
  - Congressional/insider: 24 h
  - Institutional holdings: 7 d
- **Behavior**: On miss, fetch from external API (or internal service), compute if needed, store, then return. Background refresh via Oban can warm cache for popular/watchlist tickers.

### 4.7 Background Jobs (Oban)

- **Refresh stock/institutional data**: Per-ticker or batch; respect rate limits and cache TTLs.
- **Sentiment pipeline**: Periodic pull from Reddit/news, then sentiment scoring and cache update.
- **Notifications**: Prepare payloads for Expo push (e.g. price alerts, whale alerts); actual send via Expo Push API.
- **Cleanup**: Expire old cache entries, anonymize or prune old analysis history if needed.

---

## 5. Data Flow

### 5.1 Stock Overview Request (E2E)

1. User (web or mobile) navigates to `/stocks/AAPL` (or equivalent).
2. Client calls `GET /api/stocks/AAPL` (and optionally tab-specific endpoints or a single payload).
3. Phoenix:
   - Validates JWT.
   - Checks cache for overview (or sub-responses: technical, fundamental, sentiment, institutional).
   - On cache miss: calls Analysis, Sentiment, InstitutionalActivity contexts; each may hit external APIs and sub-caches.
   - Computes overall recommendation (e.g. 30% technical + 30% fundamental + 20% sentiment + 20% institutional).
   - Caches result and returns JSON.
4. Client renders overview and tabs; can request tab-specific endpoints for lazy loading if designed that way.

### 5.2 Paper Trade Execution

1. User clicks “Trade” on stock page; modal opens with ticker, side (buy/sell), quantity.
2. Client sends `POST /api/paper-trading/portfolios/:id/trade` with `{ ticker, side, quantity }`.
3. Phoenix:
   - Validates JWT and portfolio ownership.
   - Gets current price from Stocks/cache (same 15s cache as UI).
   - Validates: sufficient cash (buy) or shares (sell), min 1 share, max 10k shares, optional 20% portfolio warning.
   - In a DB transaction: create `PaperTransaction`, update or create `PaperHolding`, update portfolio `cash_balance`.
   - Returns updated portfolio summary and transaction.
4. Client updates React Query cache and UI (holdings, cash, transaction history).

### 5.3 Institutional Data (Unusual Whales)

1. Request for options flow (or dark pool, etc.) for ticker `AAPL`.
2. Phoenix checks institutional cache (e.g. 1h TTL).
3. On miss: if rate limit allows, call Unusual Whales API; parse and normalize; store in cache and DB (if needed); return.
4. If rate limited: return last cached response with “as of” timestamp; optionally enqueue Oban job to refresh later.
5. Optional: Oban job runs during off-peak to refresh high-priority tickers (e.g. watchlist symbols).

### 5.4 Authentication Flow

1. Client submits credentials to `POST /api/auth/login`.
2. Phoenix verifies password (Bcrypt), loads user, issues JWT (Guardian) with expiry (e.g. 24h) and optional refresh token.
3. Client stores JWT (web: cookie or localStorage; mobile: SecureStore).
4. Subsequent requests: `Authorization: Bearer <token>`.
5. Phoenix pipeline verifies JWT and loads current user; context functions use `current_user` for watchlist, history, paper trading.

### 5.5 Sequence Diagrams

#### Stock overview (cache miss)

```
Client          Phoenix API         Cache          Analysis Context    External APIs
  |                   |                |                   |                   |
  | GET /stocks/AAPL  |                |                   |                   |
  |------------------>|                |                   |                   |
  |                   | get_cached     |                   |                   |
  |                   |-------------->|                   |                   |
  |                   | miss           |                   |                   |
  |                   |<--------------|                   |                   |
  |                   | get_technical  |                   |                   |
  |                   |----------------------------------->|                   |
  |                   |                |                   | fetch_alpha_vant. |
  |                   |                |                   |------------------>|
  |                   |                |                   | response          |
  |                   |                |                   |<------------------|
  |                   | technical      |                   |                   |
  |                   |<-----------------------------------|                   |
  |                   | (parallel: fundamental, sentiment, institutional)       |
  |                   | compute_recommendation (30% tech + 30% fund + 20% sent + 20% inst) |
  |                   | set_cached     |                   |                   |
  |                   |-------------->|                   |                   |
  | 200 JSON          |                |                   |                   |
  |<------------------|                |                   |                   |
```

#### Paper trade execution

```
Client          Phoenix API         PaperTrading Context    Stocks (price)    DB
  |                   |                        |                   |           |
  | POST /portfolios/1/trade                   |                   |           |
  | { ticker: AAPL, side: buy, quantity: 10 } |                   |           |
  |------------------>|                        |                   |           |
  |                   | validate JWT & ownership|                   |           |
  |                   | get_current_price(AAPL)|                   |           |
  |                   |------------------------------------------->|           |
  |                   | price 175.50           |                   |           |
  |                   |<-------------------------------------------|           |
  |                   | execute_trade(portfolio_id, AAPL, buy, 10)  |           |
  |                   |------------------------->|                 |           |
  |                   |                        | BEGIN; insert tx; update holding; update cash; COMMIT;
  |                   |                        |------------------------------------------------->|
  |                   |                        |<-------------------------------------------------|
  |                   | {:ok, transaction, portfolio}               |           |
  |                   |<-------------------------|                 |           |
  | 200 { transaction, portfolio }             |                   |           |
  |<------------------|                        |                   |           |
```

#### Unusual Whales with rate limit and fallback

```
Client          Phoenix          Cache           Institutional Context    Unusual Whales API
  |                |                |                        |                      |
  | GET /institutional/AAPL/options-flow       |                        |                      |
  |--------------->|                |                        |                      |
  |                | get_cached     |                        |                      |
  |                |-------------->|                        |                      |
  |                | miss           |                        |                      |
  |                |<--------------|                        |                      |
  |                | check_rate_limit |                      |                      |
  |                |------------------------->|             |                      |
  |                | ok / over_limit |<----------------------|                      |
  |                |                        |                      |                      |
  |     [if over limit: return last cached + 200 + "as of" timestamp; optional enqueue Oban]  |
  |     [if ok:]   | fetch_options_flow(AAPL)  |                      |                      |
  |                |----------------------------------------->|                      |
  |                |                        |                      | GET /...           |
  |                |                        |                      |------------------->|
  |                |                        |                      | 200 / 429          |
  |                |                        |                      |<-------------------|
  |                | normalize; set_cached  |                      |                      |
  |                |<-----------------------------------------|                      |
  |                | set_cached     |                        |                      |
  |                |-------------->|                        |                      |
  | 200 JSON       |                |                        |                      |
  |<---------------|                |                        |                      |
```

### 5.6 Recommendation Algorithm (Detailed)

- **Inputs**: Technical score (0–100), Fundamental score (0–100), Sentiment score (normalized to 0–100 or -100..+100 mapped), Institutional/Smart Money score (0–100).
- **Weights (PRD)**: Technical 30%, Fundamental 30%, Sentiment 20%, Institutional 20%.
- **Formula (conceptual)**:  
  `recommendation_score = 0.30*tech + 0.30*fund + 0.20*sentiment_norm + 0.20*institutional`
- **Mapping to label**: Score bands map to "Strong Sell", "Sell", "Hold", "Buy", "Strong Buy" (e.g. 0–20, 20–40, 40–60, 60–80, 80–100).
- **Confidence**: Derived from agreement of sub-scores (e.g. variance or min/max spread); or from data freshness and number of signals available.
- **Location**: Implemented in Analysis context (or a dedicated Scoring module); uses outputs from Analysis, Sentiment, and InstitutionalActivity contexts.

---

## 6. Integration Design

### 6.1 External APIs (Server-Side Only)

| Provider | Purpose | Auth | Rate / Cost Control |
|----------|---------|------|----------------------|
| Alpha Vantage | Prices, technical indicators | API key (env) | 5 req/min free; cache 15s–1h |
| Financial Modeling Prep | Fundamentals, statements | API key | 250/day free; cache 24h |
| Finnhub | News | API key | 60/min; cache per article/sentiment |
| Reddit | Subreddit posts (e.g. WSB, stocks) | PRAW or HTTP API | 60/min; cache 30min |
| Unusual Whales | Options, dark pool, congressional, insider, 13F | API key | Per-tier; 1h–7d cache; queue + Oban |
| OpenAI/Anthropic | Sentiment from text | API key | Per-request; cache 30min |

- All keys in env (e.g. Fly secrets); never sent to client.
- Phoenix modules (e.g. `StockAnalysis.Integrations.AlphaVantage`) encapsulate HTTP and error handling; return normalized structs used by contexts.

### 6.2 Client–Backend Contract

- **Transport**: HTTPS REST; optional WebSocket for live prices (Phoenix Channel).
- **Format**: JSON; error body `{ "error": "code", "message": "..." }`.
- **Auth**: Header `Authorization: Bearer <jwt>`.
- **Idempotency**: For trade execution, optional `Idempotency-Key` header to avoid double submits.

### 6.3 CORS (Phoenix)

- Allow origins: Next.js dev/prod, Expo dev, production web domain, Vercel previews; allow credentials.
- Methods: GET, POST, PUT, DELETE, OPTIONS.
- Headers: `authorization`, `content-type`, and any custom headers (e.g. idempotency-key).

### 6.4 Unusual Whales Integration (Detailed)

- **Endpoints used**: Options flow, dark pool, congressional trades, insider trades, institutional holdings (13F), market tide, smart money score.
- **Rate limit strategy**: 
  - Single queue (or per-resource) for outbound requests; max N concurrent or per-minute cap.
  - Priority: watchlist tickers > recently viewed > on-demand; background Oban jobs use lower priority.
- **Caching**: 1h options/dark pool; 24h congressional/insider; 7d holdings; responses stored by ticker + data_type + optional date range.
- **Graceful degradation**: On 429 or timeout, return last cached payload with HTTP 200 and `data_as_of` (ISO timestamp); optionally set `stale: true` in JSON. No 5xx for “out of quota” if cache exists.
- **Background refresh**: Oban job “refresh_institutional” runs on schedule (e.g. hourly); refreshes high-priority tickers (e.g. from global watchlist or top N requested) within rate limit.

### 6.5 API Endpoint Summary (Phoenix)

| Area | Method | Path | Auth | Notes |
|------|--------|------|------|-------|
| Auth | POST | /api/auth/register | No | |
| Auth | POST | /api/auth/login | No | |
| Auth | POST | /api/auth/logout | Yes | |
| Auth | POST | /api/auth/refresh | Yes | |
| Auth | POST | /api/auth/forgot-password | No | |
| Auth | POST | /api/auth/reset-password | No | |
| Stocks | GET | /api/stocks/search?q= | Yes | Autocomplete |
| Stocks | GET | /api/stocks/:ticker | Yes | Overview + recommendation |
| Stocks | GET | /api/stocks/:ticker/technical | Yes | |
| Stocks | GET | /api/stocks/:ticker/fundamental | Yes | |
| Stocks | GET | /api/stocks/:ticker/sentiment | Yes | |
| Stocks | GET | /api/stocks/:ticker/institutional | Yes | Unusual Whales aggregate |
| Stocks | GET | /api/stocks/trending | Yes | |
| Institutional | GET | /api/institutional/:ticker/options-flow | Yes | |
| Institutional | GET | /api/institutional/:ticker/dark-pool | Yes | |
| Institutional | GET | /api/institutional/:ticker/congressional | Yes | |
| Institutional | GET | /api/institutional/:ticker/insider-trades | Yes | |
| Institutional | GET | /api/institutional/:ticker/holdings | Yes | 13F |
| Institutional | GET | /api/institutional/market-tide | Yes | |
| Institutional | GET | /api/institutional/:ticker/smart-money-score | Yes | |
| User | GET/PUT | /api/user/profile | Yes | |
| User | GET | /api/user/watchlist | Yes | |
| User | POST | /api/user/watchlist | Yes | body: { ticker } |
| User | DELETE | /api/user/watchlist/:ticker | Yes | |
| User | GET | /api/user/history | Yes | Analysis history |
| Shares | POST | /api/shares/create | Yes | body: { type, payload_ref } |
| Shares | GET | /api/shares/:id | No | Public share link |
| Paper | GET | /api/paper-trading/portfolios | Yes | |
| Paper | POST | /api/paper-trading/portfolios | Yes | Create |
| Paper | GET | /api/paper-trading/portfolios/:id | Yes | |
| Paper | PUT | /api/paper-trading/portfolios/:id | Yes | |
| Paper | DELETE | /api/paper-trading/portfolios/:id | Yes | |
| Paper | GET | /api/paper-trading/portfolios/:id/performance | Yes | |
| Paper | POST | /api/paper-trading/portfolios/:id/trade | Yes | body: { ticker, side, quantity } |
| Paper | GET | /api/paper-trading/portfolios/:id/holdings | Yes | |
| Paper | GET | /api/paper-trading/portfolios/:id/transactions | Yes | Paginated |
| Paper | GET | /api/paper-trading/portfolios/:id/transactions/:tx_id | Yes | |
| Paper | POST | /api/paper-trading/portfolios/:id/share | Yes | Shareable snapshot |
| Paper | GET | /api/paper-trading/leaderboard | Yes | Phase 2 |

---

## 7. Data Model (Conceptual)

### 7.1 Core Entities

- **User**: id, email, password_hash, username, email_verified, avatar_url, timestamps.
- **Watchlist**: user_id, ticker, added_at (unique per user+ticker).
- **AnalysisHistory**: user_id, ticker, viewed_at (for “last 20”).
- **PaperPortfolio**: user_id, name, description, starting_balance, cash_balance, is_active.
- **PaperHolding**: portfolio_id, ticker, quantity, average_cost, total_cost, last_updated.
- **PaperTransaction**: portfolio_id, ticker, transaction_type (buy/sell), quantity, price_per_share, total_amount, recommendation_at_time, notes, executed_at.
- **StockCache** (optional DB-backed cache): ticker, data_type, data (jsonb), expires_at.
- **Share** (shareable link): id (short), payload_type (analysis|portfolio), payload (jsonb or refs), expires_at, created_at.

### 7.2 Important Relationships

- User → Watchlist (one-to-many); User → AnalysisHistory (one-to-many); User → PaperPortfolio (one-to-many).
- PaperPortfolio → PaperHolding (one-to-many); PaperPortfolio → PaperTransaction (one-to-many).
- No strong reference from application DB to external ticker “master”; ticker is string key.

### 7.3 Indexes (Recommendations)

- Watchlist: `(user_id, ticker)` unique; `user_id` for list.
- AnalysisHistory: `(user_id, viewed_at DESC)` for last N.
- PaperTransaction: `(portfolio_id, executed_at DESC)`, `(portfolio_id, ticker)`.
- PaperHolding: `(portfolio_id, ticker)` unique.

---

## 8. Security Architecture

### 8.1 Authentication

- **Issue**: Guardian JWT with short-lived access token; optional refresh token stored in DB or signed.
- **Storage**: Web — httpOnly cookie preferred, or memory + refresh; Mobile — SecureStore only.
- **Validation**: Every protected route verifies JWT signature and expiry; loads user and attaches to connection.

### 8.2 Authorization

- **Resource ownership**: Paper trading and watchlist scoped by `current_user.id`; no cross-user access.
- **Shares**: Public share links are unauthenticated; link ID must be unguessable (random short id or UUID).

### 8.3 Data Protection

- **Passwords**: Bcrypt (or Argon2) with safe cost factor.
- **Transport**: TLS only (Vercel/Fly.io provide HTTPS).
- **Secrets**: API keys and `SECRET_KEY_BASE` in environment (Fly secrets / Vercel env); never in repo.

### 8.4 Input and Output

- **Validation**: Ecto changesets for all writes; Zod (or equivalent) in api-client for request/response typing.
- **Output**: No PII or internal IDs in error messages; generic messages for auth failures.

---

## 9. Scalability and Performance

### 9.1 Caching

- **Layered**: ETS/Redis for API responses; DB for persistent data only.
- **TTLs**: As in PRD; shorter for price, longer for fundamentals and 13F.
- **Invalidation**: TTL-based only for MVP; no explicit invalidation required for correctness.

### 9.2 Rate Limiting

- **External APIs**: Per-provider limits enforced in integration layer; queue or backoff when exceeded.
- **Unusual Whales**: Priority queue (e.g. watchlist first); return cached + “as of” when over limit.
- **User-facing**: Optional per-user or per-IP rate limit on expensive endpoints (e.g. stock overview) to protect backend.

### 9.3 Async and Background

- **Oban**: All long-running or rate-limited external calls that are not request-critical run in jobs; request path returns from cache or fast path only.
- **WebSocket**: Optional Channel for “live” price updates; backend pushes when cache is refreshed or on interval.

### 9.4 Scaling

- **Phoenix**: Horizontal scaling behind load balancer; shared Redis cache and PostgreSQL; no in-memory session state.
- **Next.js**: Vercel serverless/edge scales by request.
- **Mobile**: Client-side only; scale with user count via same API.

---

## 10. Observability and Operations

### 10.1 Logging

- **Structured logs**: Request id, user id (if any), path, status, duration; no passwords or tokens.
- **Integration logs**: Provider name, ticker, cache hit/miss, rate limit events; optional error stack for 5xx.

### 10.2 Metrics (Recommended)

- **API**: Request count and latency by route and status (e.g. Prometheus/StatsD or Fly/Vercel metrics).
- **Cache**: Hit rate by key prefix or data type.
- **External**: Call count and errors per provider; Unusual Whales usage vs limit.
- **Paper trading**: Trades per day, active portfolios.

### 10.3 Error Handling

- **Client**: Retry with backoff for 5xx and network errors; show “Data may be outdated” when using stale cache.
- **Server**: Error boundaries in Next.js; Phoenix fallback controller for 500; never leak stack to client in production.

### 10.4 Health

- **Phoenix**: `/health` or `/api/health` that checks DB connectivity and optionally cache; returns 200 or 503.
- **Vercel**: Default health or use same API health for monitoring.

---

## 11. Deployment and CI/CD

### 11.1 Environments

- **Development**: Local Phoenix, local or dev PostgreSQL; web and mobile point to local API; env in `.env.local` / `.env`.
- **Staging** (optional): Same as production but with staging API keys and DB.
- **Production**: Vercel (web), Fly.io (API + PostgreSQL), EAS (mobile builds and OTA).

### 11.2 Build and Release

- **Monorepo**: `pnpm install` at root; `turbo build` for all apps; filter by app for per-app deploy.
- **Web**: Vercel build from `apps/web`; env in Vercel dashboard.
- **API**: `mix release`; deploy to Fly.io with `fly deploy`; migrations run before or during deploy.
- **Mobile**: EAS Build from `apps/mobile`; submit to stores via EAS Submit; OTA via `eas update`.

### 11.3 Secrets and Config

- **Phoenix**: `SECRET_KEY_BASE`, `DATABASE_URL`, `ALPHA_VANTAGE_API_KEY`, `FMP_API_KEY`, `UNUSUAL_WHALES_API_KEY`, etc. in Fly secrets.
- **Next.js**: `NEXT_PUBLIC_API_URL` (and any other public vars) in Vercel.
- **Mobile**: `EXPO_PUBLIC_API_URL` in EAS env or app config; no secret keys in app.

---

## 12. Logical Milestones

Each milestone is a coherent, testable slice. HLD section references point to where the design is described.

---

### 12.1 Milestone 1 — Foundation

**Goal**: Monorepo, auth, API skeleton, and deploy pipeline so web and mobile can call a single backend.

**Dependencies**: None.

**Deliverables**

| Layer | Deliverables |
|-------|--------------|
| **Monorepo** | Turborepo + PNPM; `apps/web`, `apps/mobile`, `apps/api`; `packages/types`, `api-client`, `ui`, `tailwind-config`, `typescript-config`, `utils`. Root scripts: `dev`, `build`, `lint`, `type-check`. |
| **API** | Phoenix project in `apps/api`; PostgreSQL; Ecto; Guardian JWT. Accounts context: register, login, refresh, password reset (optional). CORS configured for web + Expo. Health endpoint. |
| **Web** | Next.js 14+ in `apps/web`; App Router; Tailwind (extends shared config). Auth UI: login, register; token storage; protected route middleware. Uses `@repo/api-client`, `@repo/types`, `@repo/ui`. |
| **Mobile** | Expo app in `apps/mobile`; Expo Router; NativeWind. Auth screens: login, register; JWT in SecureStore. Uses same shared packages. |
| **Deploy** | Phoenix on Fly.io; Next.js on Vercel; env and secrets wired. EAS project for mobile (dev build testable). |

**HLD sections**: §3 Architecture, §4.1 Packages, §4.4 Accounts context, §4.5 API layer, §5.4 Auth flow, §6.2 Client–backend contract, §6.3 CORS, §7 Data model (User), §8 Security, §11 Deployment.

**Acceptance criteria**

- User can register and log in on web and mobile; JWT accepted by API.
- `pnpm dev` runs web + mobile dev servers; API runs via `mix phx.server`.
- Web and mobile call same API URL; CORS allows both.
- Phoenix and Next.js deploy successfully; health check returns 200.

---

### 12.2 Milestone 2 — Stock Analysis Core

**Goal**: Technical analysis and stock overview on web and mobile; one analysis tab (Technical) and basic institutional data.

**Dependencies**: M1.

**Deliverables**

| Layer | Deliverables |
|-------|--------------|
| **API** | Stocks context: search (autocomplete), overview aggregation. Analysis context: Alpha Vantage integration, technical indicators (e.g. RSI, MACD, SMA), technical score. Cache layer (ETS): 15s price, 1h technical. Basic InstitutionalActivity: Unusual Whales options flow + dark pool for a ticker; cache 1h. |
| **Web** | Stock search (autocomplete); `/stocks/[ticker]` with overview (price, change, recommendation placeholder), Technical tab with chart (e.g. Lightweight Charts) and indicators. Optional Institutional section (options/dark pool). |
| **Mobile** | Tab layout (Home, Portfolio placeholder, Watchlist placeholder); stock search; stock detail with Technical tab and chart (e.g. Victory Native). Same API client and types as web. |

**HLD sections**: §4.4 Stocks, Analysis, InstitutionalActivity (basic), §4.6 Cache, §5.1 Stock overview flow, §5.5 Sequence (stock overview), §6.1 External APIs (Alpha Vantage, Unusual Whales), §6.4 Unusual Whales integration, §7 Data model (no new DB for M2 beyond User).

**Acceptance criteria**

- Search returns tickers; selecting a ticker loads overview and technical data.
- Technical tab shows price chart and at least one indicator; data cached per TTL.
- Unusual Whales options/dark pool visible for a ticker (with “as of” when cached).
- Web and mobile both render stock overview and Technical tab from same API.

---

### 12.3 Milestone 3 — Full Analysis & Institutional

**Goal**: All four analysis dimensions (Technical, Fundamental, Emotional, Institutional) and the combined recommendation algorithm; full Institutional tab.

**Dependencies**: M2.

**Deliverables**

| Layer | Deliverables |
|-------|--------------|
| **API** | Analysis: FMP integration; fundamental metrics and score; cache 24h. Sentiment context: Reddit (PRAW or HTTP), optional news (Finnhub), sentiment engine (LLM or FinBERT); cache 30min. InstitutionalActivity: congressional, insider, 13F holdings, market tide, smart money score; rate limit and cache per §6.4. Recommendation algorithm: 30/30/20/20 weights, score → label, confidence. |
| **Web** | Fundamental tab (ratios, statements, company overview). Emotional tab (sentiment gauge, Reddit, news, smart money subsection). Full Institutional tab (options flow, dark pool, congressional, insider, holdings). Recommendation badge and confidence on overview. |
| **Mobile** | All four tabs with same data; layout adapted for native (lists, charts, cards). |

**HLD sections**: §4.4 Analysis, Sentiment, InstitutionalActivity (full), §5.1 Stock overview, §5.6 Recommendation algorithm, §6.1 FMP, Finnhub, Reddit, sentiment API, §6.4 Unusual Whales, §6.5 API endpoints (stocks + institutional).

**Acceptance criteria**

- Overview shows recommendation (Strong Buy/Buy/Hold/Sell/Strong Sell) and confidence.
- All four tabs load; Fundamental and Emotional show real data from FMP and sentiment pipeline.
- Institutional tab shows options flow, dark pool, congressional, insider, holdings with correct cache/rate-limit behavior.
- Recommendation matches weighted combination of the four scores.

---

### 12.4 Milestone 4 — Paper Trading

**Goal**: End-to-end paper trading: create portfolio, execute market orders, view holdings and transaction history, basic performance.

**Dependencies**: M2 (price source); can parallelize with M3.

**Deliverables**

| Layer | Deliverables |
|-------|--------------|
| **API** | PaperTrading context: create/get/update portfolio; execute trade (buy/sell, market order); update holdings and cash; transaction history (paginated). Performance: total value, gain/loss, win rate, best/worst trade. Trade validation: cash/shares, min/max size, optional 20% warning. |
| **Web** | Portfolio dashboard (value, cash, holdings table, performance cards); trade modal from stock page (buy/sell, quantity, preview); transaction history with filters; performance chart (e.g. 1W/1M/3M/1Y). |
| **Mobile** | Portfolio tab (dashboard, holdings, performance); trade flow (e.g. bottom sheet); transaction list; charts (Victory Native or similar). |

**HLD sections**: §4.4 PaperTrading context, §5.2 Paper trade execution, §5.5 Sequence (paper trade), §6.5 API (paper-trading), §7 PaperPortfolio, PaperHolding, PaperTransaction.

**Acceptance criteria**

- User can create a portfolio and execute buy/sell; holdings and cash update correctly.
- Transaction history is accurate and paginated; trade shows “executed at” price.
- Performance metrics (return %, win rate) computed correctly.
- Trade from stock page pre-fills ticker; “Add to Portfolio” flows work on web and mobile.

---

### 12.5 Milestone 5 — Engagement & Sharing

**Goal**: Watchlist, analysis history, shareable links, push notifications, and background refresh.

**Dependencies**: M2, M3, M4 (for portfolio share).

**Deliverables**

| Layer | Deliverables |
|-------|--------------|
| **API** | Watchlist context: add/remove, list. Analysis history: record last N viewed tickers, list. Shares context: create share link (analysis or portfolio snapshot), public GET by id. Oban: jobs to refresh cache for popular/watchlist tickers; optional notification payload prep. Expo Push integration for sending push (e.g. price/whale alerts). |
| **Web** | Watchlist page; add/remove from stock page; recent history. Share button → create link; public share view (read-only). Profile and notification preferences. |
| **Mobile** | Watchlist tab; history; share flow. Push: register device, receive alerts; optional biometric polish. |

**HLD sections**: §4.4 Watchlist, Shares, §4.7 Oban (refresh, notifications), §6.5 API (user watchlist/history, shares, paper share), §7 Watchlist, AnalysisHistory, Share.

**Acceptance criteria**

- User can add/remove watchlist and see analysis history.
- Share link is public and shows analysis or portfolio snapshot without auth.
- Oban jobs run and refresh cache; no duplicate work beyond rate limits.
- Push notifications delivered for configured alerts (e.g. price, whale activity).

---

### 12.6 Milestone 6 — Polish & Scale

**Goal**: App store submission, optional Redis, performance tuning, and advanced features (per PRD Phase 4).

**Dependencies**: M1–M5.

**Deliverables**

| Layer | Deliverables |
|-------|--------------|
| **Infra** | Redis for cache if multi-node Phoenix; Oban tuning; monitoring and alerts. |
| **Web** | Performance (e.g. RSC boundaries, code split); SEO and metadata; error boundaries; analytics. |
| **Mobile** | App icon, splash, store listings; TestFlight/Internal Testing; store submission (iOS + Android); crash reporting (e.g. Sentry); OTA updates. |
| **Features** | Optional: leaderboard, achievements, multiple portfolios, limit/stop orders, richer institutional analytics, PDF/CSV export. |

**HLD sections**: §4.6 Cache (Redis), §9 Scalability, §10 Observability, §11 Deployment, PRD Phase 4.

**Acceptance criteria**

- Web and API meet target latency and error rate; cache hit rate tracked.
- Mobile apps approved (or in review) on App Store and Google Play; OTA works.
- Optional Phase 4 features implemented as scoped.

---

### 12.7 Milestone Summary Table

| Milestone | Backend (Phoenix) | Web | Mobile | Deploy / Infra |
|-----------|-------------------|-----|--------|----------------|
| **M1** | Accounts, CORS, health | Auth, Next.js shell | Auth, Expo shell | Fly, Vercel, EAS |
| **M2** | Stocks, Analysis (technical), Cache, basic Institutional | Search, stock page, Technical tab | Tabs, search, stock + Technical | Same |
| **M3** | FMP, Sentiment, full Institutional, recommendation | Fundamental, Emotional, Institutional tabs | All 4 tabs | Same |
| **M4** | PaperTrading (portfolios, trades, performance) | Portfolio dashboard, trade modal, history | Portfolio tab, trade, history | Same |
| **M5** | Watchlist, history, Shares, Oban, Push | Watchlist, share, profile | Watchlist, share, push | Same |
| **M6** | Redis optional, Oban tune | Perf, SEO, analytics | Store submit, OTA, Sentry | Monitoring, stores |

---

## 13. Glossary (Selected)

- **ETS**: Erlang Term Storage; in-memory key-value store used for Phoenix cache.
- **Oban**: Elixir job queue using PostgreSQL for persistence.
- **Guardian**: Elixir JWT library used for token issue and verification.
- **RSC**: React Server Components (Next.js).
- **NativeWind**: Tailwind CSS for React Native.
- **EAS**: Expo Application Services (build, submit, updates).

---

## 14. References

- **PRD**: mnml_prd.md (Product Requirements Document v3.0)
- **API docs**: To be maintained (OpenAPI/Swagger) in repo or separate doc.
- **External API docs**: Alpha Vantage, FMP, Finnhub, PRAW, Unusual Whales, OpenAI/Claude — see PRD Appendix.

---

**Document Version**: 1.0  
**Last Updated**: February 24, 2026  
**Next Review**: After Phase 1 implementation

# Milestone 7 — Multi-Agent LLM Analysis: Tickets

**Goal**: Explore and implement a TradingAgents-style multi-agent LLM framework that consumes existing stock data (Alpha Vantage, Unusual Whales, technical analysis, fundamentals) and produces synthesized analysis, debate, and optional trade-style signals—integrated with the API, web, and mobile.  
**Dependencies**: M1–M6 (auth, stocks, analysis, paper trading, watchlist).  
**HLD reference**: §12.7 Logical Milestones — Milestone 7.  
**Inspiration**: [TradingAgents](https://github.com/TauricResearch/TradingAgents) (Apache 2.0): analyst agents, researcher debate, trader/risk layers—adapted to our stack and data sources.

---

## M7-001: Research and design — agent architecture

### Ticket
**ID**: M7-001  
**Title**: Research and design — multi-agent LLM architecture and integration strategy

### Description (why this ticket is needed)
Before building, we need a clear design: how agent roles map to our existing data (Stocks context, Analysis context, Alpha Vantage, Unusual Whales), whether to implement in Elixir or as a Python sidecar, how results are cached and exposed via the API, and how the pipeline ties into watchlist, paper trading, and UI.

### Required tasks
- [x] Document TradingAgents-style roles relevant to our stack: **Technical Analyst** (our indicators + price), **Fundamental/Sentiment** (M3 data when available; or summary from overview), **Institutional Analyst** (options flow, dark pool from Unusual Whales), **Researcher** (bull/bear debate over analyst outputs), **Trader Agent** (synthesized view → optional "consideration" or paper-trade suggestion), **Risk** (guardrails, optional approval).
- [x] Decide integration approach: **Option A** — Elixir-native (HTTP client to OpenAI/Claude/etc., orchestration in Phoenix, cache in ETS/Redis); **Option B** — Python service (TradingAgents or minimal clone) called by Phoenix; **Option C** — hybrid (e.g. single "summary" agent in Elixir first, expand later). Document pros/cons and chosen path.
- [x] Define data flow: which existing API responses (stock overview, technical, options flow, etc.) are passed into which agents; where results are stored (e.g. `agent_analysis` table or cache key per ticker); TTL and invalidation. **BYOK**: Load current user's LLM settings (provider + decrypted API key) before any LLM call; if user has not configured an API key, return 403 with message to configure in Settings.
- [x] Define API contract: e.g. `GET /api/stocks/:ticker/agent-analysis` (and optionally batch for watchlist); response shape (summary, debate excerpt, optional "consideration" label). **Auth**: 401 if unauthenticated; 403 if user has not configured an LLM API key (message: "Add your API key in Settings to enable AI analysis").
- [ ] Add a short "Multi-Agent Analysis" section to HLD or design doc referencing this milestone.
- [x] **BYOK and multi-provider**: No app-level LLM key required for production. Users configure provider (OpenAI, Anthropic, etc.) and API key in profile/settings. Agent pipeline runs with the **current user's** credentials. Cache key can be `agent_analysis:{ticker}` (shared) or `agent_analysis:{user_id}:{ticker}` (per-user). Optional: app-level key in dev only for testing without per-user keys.

### Acceptance criteria
- Written design doc (or HLD section) that specifies agent roles, data inputs, integration approach (Elixir vs Python), API contract, and cache strategy.
- Decision recorded: **multi-provider BYOK from the start**; no app-level LLM key required in production.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Review design doc | All roles and data sources clearly mapped |
| 2 | Confirm API contract with existing api-client/types | Compatible with web/mobile consumption |

---

## M7-002: LLM provider integration (Phoenix)

### Ticket
**ID**: M7-002  
**Title**: LLM provider integration — behaviour, adapters (OpenAI, Anthropic), key per request from user settings

### Description (why this ticket is needed)
The app needs a reliable way to call an LLM (OpenAI, Anthropic, or other) from Elixir. API key is supplied **per request** from the current user's encrypted settings (BYOK); no app-level key is required in production. This ticket establishes the behaviour and adapters so the agent pipeline can call the user's chosen provider with their key.

### Required tasks
- [x] Add dependency for HTTP LLM calls (e.g. `req` already in use) to OpenAI/Anthropic APIs.
- [x] Create a behaviour (e.g. `StockAnalysis.AgentAnalysis.LLMAdapter`) with `complete(provider, api_key, prompt, options)` returning `{:ok, text}` or `{:error, reason}`; support configurable model and max_tokens passed in options.
- [x] Implement OpenAI adapter: chat completions using passed-in `api_key`; timeout (e.g. 30s).
- [x] Implement Anthropic adapter: Messages API using passed-in `api_key`; timeout (e.g. 30s).
- [ ] Optional dev fallback: config flag `use_app_llm_key_in_dev`; when true and user has no key, use env `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` for testing only.

### Acceptance criteria
- Phoenix can call the LLM with a prompt and receive plain-text completion; key is passed per call (from user settings).
- No app-level LLM key required for production; feature works when user has configured provider and key in settings.
- Multiple providers (OpenAI, Anthropic) supported behind the same behaviour.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Set env var; call LLM module with simple prompt | Returns `{:ok, "..."}` with non-empty text |
| 2 | Unset API key; restart | Config loads; LLM calls return error or skip without crash |
| 3 | Grep repo for API key string | Not present in source |

---

## M7-003: Analyst agents — technical and institutional

### Ticket
**ID**: M7-003  
**Title**: Analyst agents — technical and institutional (LLM summaries from existing data)

### Description (why this ticket is needed)
Users benefit from a short, natural-language summary of what the numbers mean. This ticket implements two "analyst" agents that consume data we already have: (1) Technical Analyst — overview + indicators + score; (2) Institutional Analyst — options flow and dark pool summary. Both use the LLM to produce a concise paragraph (or bullets) suitable for the stock detail UI.

### Required tasks
- [x] **Technical Analyst**: Build a prompt that includes ticker, price, change, key metrics, technical indicators (RSI, MACD, etc.), and technical score. Call LLM; parse and sanitize response (strip markdown if needed, length limit). Return structured result (e.g. `%{role: "technical", summary: "..."}`).
- [x] **Institutional Analyst**: Build a prompt that includes ticker, recent options flow summary, dark pool summary (from Unusual Whales integration). Call LLM; return structured result (e.g. `%{role: "institutional", summary: "..."}`).
- [x] Fetch required data via existing contexts (Stocks, Analysis, Unusual Whales); do not duplicate API calls—use cached/context data passed into the agent module.
- [ ] Add unit tests or integration tests that stub LLM response and assert output shape and that no raw secrets appear in prompts.

### Acceptance criteria
- Technical Analyst produces a short summary from overview + technical data.
- Institutional Analyst produces a short summary from options/dark pool data.
- Both use existing API/cache; no new external data sources.
- Outputs are safe to display in UI (no injection; length bounded).

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Call Technical Analyst with fixture overview + indicators | Returns summary string |
| 2 | Call Institutional Analyst with fixture options/dark pool | Returns summary string |
| 3 | Request analysis for ticker with missing institutional data | Graceful fallback (e.g. "No recent institutional data") |

---

## M7-004: Researcher layer — bull/bear debate

### Ticket
**ID**: M7-004  
**Title**: Researcher layer — bull and bear debate from analyst outputs

### Description (why this ticket is needed)
A TradingAgents-style "researcher" step adds balance: one agent argues bull case, one bear case, based on the same analyst summaries. This gives users a quick pros/cons view and reduces single-perspective bias. The output is consumed by the synthesis step or shown directly in the UI.

### Required tasks
- [x] Define input: concatenated or structured output from Technical and Institutional analysts (and optionally Fundamental/Sentiment when M3 data exists).
- [x] **Bull researcher**: Prompt that asks for 2–4 bullet points supporting a bullish view given the data. Call LLM; return structured result.
- [x] **Bear researcher**: Prompt that asks for 2–4 bullet points supporting a bearish view given the data. Call LLM; return structured result.
- [x] Optionally combine into a single "debate" call (e.g. "Given the following analysis, list key bull and key bear points") to save latency and cost.
- [x] Cache debate result per ticker (same TTL strategy as agent analysis) to avoid re-running on every request.

### Acceptance criteria
- Bull and bear points are generated from the same analyst inputs.
- Output is structured (e.g. `{bull: ["..."], bear: ["..."]}`) and length-bounded.
- Debate is cached; cache key includes ticker and optionally data version.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Run researchers with fixed analyst output | Both bull and bear lists non-empty |
| 2 | Request debate for same ticker twice within TTL | Second request uses cache (no extra LLM call) |

---

## M7-005: Synthesis and optional "consideration" signal

### Ticket
**ID**: M7-005  
**Title**: Synthesis — combined summary and optional trade consideration

### Description (why this ticket is needed)
The final step combines analyst summaries and debate into one coherent "agent analysis" and, optionally, a simple label (e.g. "Worth a look" / "Neutral" / "Caution") that the UI can show and that could later feed into paper-trading suggestions. This ticket does not execute trades; it only produces a synthesized view and an optional consideration tag.

### Required tasks
- [x] **Synthesis agent**: Prompt that takes technical summary, institutional summary, and bull/bear points; outputs one short paragraph (2–4 sentences) and optionally a single "consideration" label. Call LLM; parse response into `%{summary: "...", consideration: "..."}` (consideration optional).
- [x] **Orchestration**: Implement a pipeline (e.g. in `StockAnalysis.AgentAnalysis` context): fetch data → Technical Analyst → Institutional Analyst → Researchers → Synthesis. Run in sequence or parallel where independent; respect timeouts and abort on critical failure.
- [x] **Persistence/cache**: Store or cache the full result (all analyst outputs + debate + synthesis) under a key like `agent_analysis:{ticker}` with TTL (e.g. 1–4 hours) so UI and API can serve it without re-running every time.
- [x] Define "risk" guardrails: e.g. no explicit "buy/sell" in synthesis; disclaimer that output is for research only, not advice. Enforce in prompt and/or post-processing.

### Acceptance criteria
- Full pipeline runs for a given ticker and produces synthesis + optional consideration.
- Result is cached with defined TTL.
- Output includes disclaimer or is clearly framed as research-only.
- Pipeline fails gracefully (e.g. returns partial result or error) if LLM or data is unavailable.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Request agent analysis for AAPL | Cached result with summary and consideration |
| 2 | Request again within TTL | Same result from cache; no new LLM calls |
| 3 | Simulate LLM timeout | Partial or error response; no crash |

---

## M7-006: API and types — agent analysis endpoint

### Ticket
**ID**: M7-006  
**Title**: API and shared types — expose agent analysis to web and mobile

### Description (why this ticket is needed)
Web and mobile need a stable endpoint and types to display the multi-agent analysis on the stock detail page. This ticket adds the HTTP contract, auth, and shared TypeScript types so both clients can render summary, debate, and consideration consistently.

### Required tasks
- [x] Add `GET /api/stocks/:ticker/agent-analysis` (auth required). Returns JSON: `{ summary, consideration?, technicalSummary?, institutionalSummary?, bullPoints?, bearPoints?, cachedAt? }`. Trigger pipeline if not cached (or return 202 + poll, or synchronous—per design from M7-001).
- [x] Add Ecto schema/migration if storing in DB (e.g. `agent_analyses`: user_id optional, ticker, payload JSONB, inserted_at); or document "cache only" and return from cache with `cachedAt`.
- [x] Add types in `@repo/types` and methods in `@repo/api-client` for agent analysis. Add to openapi/spec if present.
- [x] Document in API docs or README: endpoint, rate limits (if any), and that analysis is for research only.
- [x] **Auth and BYOK**: 401 when unauthenticated; **403 when the user has not configured an LLM API key** — response message: "Add your API key in Settings to enable AI analysis" (or equivalent) so clients can show a CTA linking to profile/settings.

### Acceptance criteria
- Authenticated GET returns agent analysis for the ticker; unauthenticated returns 401; **403 when user has not configured an API key**, with message directing them to Settings.
- Response shape matches shared types; web and mobile can consume it.
- Invalid ticker returns 404 or empty analysis per product decision.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | GET with valid token and ticker | 200, JSON with summary and optional fields |
| 2 | GET without token | 401 |
| 3 | GET for ticker with no cached analysis | 200 with pipeline run, or 202 + location per design |

---

## M7-007: Web UI — agent analysis on stock detail

### Ticket
**ID**: M7-007  
**Title**: Web UI — agent analysis block on stock detail page

### Description (why this ticket is needed)
The stock detail page should show the synthesized agent analysis: summary paragraph, optional bull/bear bullets, and consideration badge. This gives users a single place to read both raw data (tabs) and the LLM-derived narrative.

### Required tasks
- [x] Add a section or tab "AI Analysis" (or "Summary") on the stock detail page that fetches `GET /api/stocks/:ticker/agent-analysis` and displays summary, consideration, and optionally bull/bear points.
- [x] Use existing api-client and types; show loading state and handle errors (e.g. "Analysis unavailable"). **When the API returns 403 (user has not configured API key)**, show an inline message: "Add your API key in Settings to enable AI analysis" and link to profile/settings.
- [x] Include short disclaimer: "For research only; not investment advice."
- [x] Ensure layout works on mobile viewport (responsive).

### Acceptance criteria
- Agent analysis section visible on stock detail when data is available.
- Loading and error states are handled.
- Disclaimer is visible; no misleading "buy/sell" wording from UI.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Open /stocks/AAPL; scroll to AI Analysis | Summary and consideration visible (or loading then content) |
| 2 | Open stock with agent analysis disabled or failed | Graceful message or hidden section |
| 3 | Resize to mobile width | Section readable and not broken |

---

## M7-008: Mobile UI — agent analysis on stock screen

### Ticket
**ID**: M7-008  
**Title**: Mobile UI — agent analysis on stock detail screen

### Description (why this ticket is needed)
Mobile users should see the same agent analysis (summary, consideration, bull/bear) on the stock detail screen so the experience is consistent with web and they can quickly scan the AI-derived view on the go.

### Required tasks
- [x] Add "AI Analysis" section or collapsible block on the stock detail screen; call `api.getAgentAnalysis(ticker)` and display summary, consideration badge, and optional bull/bear lists.
- [x] Reuse shared types and api-client; match web disclaimer and tone. **When the API returns 403 (no API key configured)**, show inline message and link to profile/settings to add key.
- [x] Handle loading and error states; avoid blocking the rest of the screen if the agent endpoint is slow or fails.

### Acceptance criteria
- Agent analysis visible on mobile stock detail when available.
- Layout fits small screens; text readable.
- Same disclaimer as web; no investment advice claim.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Open stock detail on device/simulator | AI Analysis section shows summary (or loading) |
| 2 | Tap to expand bull/bear if collapsed | Points displayed |
| 3 | Turn off network; open stock | Error state or cached analysis if previously loaded |

---

## M7-009: Watchlist and batch (optional)

### Ticket
**ID**: M7-009  
**Title**: Agent analysis for watchlist — batch or on-demand

### Description (why this ticket is needed)
Users with a watchlist may want to see agent summaries for multiple tickers without opening each one. This ticket adds a way to request or precompute agent analysis for watchlist tickers (e.g. batch endpoint or background job) and optionally surface a short "consideration" or summary on the watchlist UI.

### Required tasks
- [ ] **Option A**: `GET /api/user/watchlist/agent-summaries` — returns list of `{ticker, summary?, consideration?, cachedAt}` for the user's watchlist; trigger pipeline for missing/stale entries (async or sync per design).
- [ ] **Option B**: Oban job that precomputes agent analysis for each watchlist ticker on a schedule (e.g. daily or when user adds ticker); API only reads from cache.
- [ ] **Per-user key**: Batch/watchlist uses the same per-user LLM credentials (BYOK); rate and cost are determined by each user's own provider/limits.
- [ ] Document rate/cost implications (LLM calls per user/watchlist size); add limits if needed (e.g. max 10 tickers per batch, or only cached).
- [ ] (Optional) Add a compact "AI take" or consideration badge next to each ticker on the watchlist page (web and/or mobile).

### Acceptance criteria
- Watchlist can be associated with agent analysis (batch or precomputed).
- No unbounded LLM usage; limits or caching strategy documented and enforced.
- Optional UI shows at least consideration or "summary available" on watchlist.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Add 3 tickers to watchlist; call batch endpoint or wait for job | Each ticker has agent analysis or pending state |
| 2 | Exceed batch limit (if any) | Clear error or truncation |

---

## M7-010: Documentation and disclaimer

### Ticket
**ID**: M7-010  
**Title**: Documentation and legal disclaimer for agent analysis

### Description (why this ticket is needed)
Multi-agent LLM output must be clearly framed as research/educational only, not investment advice. Documentation helps operators run and tune the feature; a clear disclaimer protects users and the product.

### Required tasks
- [x] Add "Multi-Agent Analysis" section to README or docs: what it is, which data it uses, that it is **user-funded (BYOK)** — users configure provider and API key in profile/settings — and that it is for research only.
- [x] Ensure in-app disclaimer is visible wherever agent analysis is shown (web and mobile): e.g. "AI-generated analysis for research only; not investment advice."
- [x] Document env vars: **`LLM_SETTINGS_ENCRYPTION_KEY`** (required in production for encrypting user API keys at rest); **`OPENAI_API_KEY` / `ANTHROPIC_API_KEY`** only as **optional dev fallback** (when enabled in config) for testing without per-user keys — not required in production.
- [ ] (Optional) Add a link to a short "How we use AI" or "Research disclaimer" page in app footer or profile.

### Acceptance criteria
- README or docs describe the feature and configuration.
- Disclaimer is present in UI wherever agent analysis is displayed.
- No claim that the system provides investment advice.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Read README multi-agent section | Clear description and env vars |
| 2 | View agent analysis on web and mobile | Disclaimer text visible |

---

## Milestone 7 completion checklist

- [x] M7-001: Research and design — agent architecture
- [x] M7-002: LLM provider integration (Phoenix)
- [x] M7-003: Analyst agents — technical and institutional
- [x] M7-004: Researcher layer — bull/bear debate
- [x] M7-005: Synthesis and optional consideration signal
- [x] M7-006: API and types — agent analysis endpoint
- [x] M7-007: Web UI — agent analysis on stock detail
- [x] M7-008: Mobile UI — agent analysis on stock screen
- [ ] M7-009: Watchlist and batch (optional)
- [x] M7-010: Documentation and disclaimer

**Done when**: Multi-agent LLM analysis is designed and implemented; Technical and Institutional analysts plus Researcher debate and Synthesis run in Phoenix (or approved sidecar); API exposes agent analysis; web and mobile show summary and consideration with clear research-only disclaimer; optional watchlist integration and full documentation in place.

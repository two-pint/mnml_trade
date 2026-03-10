# Milestone 8 — Polish & Scale: Tickets

**Goal**: App store submission, optional Redis, performance tuning, observability, and advanced features.  
**Dependencies**: M1–M7.  
**HLD reference**: §12.8 Logical Milestones — Milestone 8.

---

## M8-001: Redis cache (optional multi-node)

### Ticket
**ID**: M8-001  
**Title**: Redis cache for multi-node Phoenix

### Description (why this ticket is needed)
ETS is per-node; if Phoenix is scaled to multiple instances behind a load balancer, each node has its own cache, leading to duplicate external API calls and inconsistent responses. Redis provides a shared cache layer that all nodes read/write. This ticket is only needed if scaling beyond a single Phoenix instance; it can be deferred if traffic stays low.

### Required tasks
- [ ] Add Redis client dependency (e.g. `Redix` or `Cachex` with Redis adapter).
- [ ] Create a cache adapter interface (e.g. behaviour) so the app can switch between ETS and Redis via config.
- [ ] Update `StockAnalysis.Cache` to use the adapter: in dev/test use ETS, in production use Redis (when configured).
- [ ] Provision Redis (e.g. Upstash, Redis Cloud, or Fly Redis). Set `REDIS_URL` in Fly secrets.
- [ ] Verify all existing cache operations (put, get, TTL) work with Redis.
- [ ] Load test: verify two Phoenix nodes share cache (one writes, other reads).

### Acceptance criteria
- Cache adapter is swappable via config.
- All existing cache keys and TTLs work identically on Redis.
- Two Phoenix nodes share the same cache when using Redis.
- Falls back to ETS if Redis is not configured.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Configure Redis in test env; run `mix test` for cache module | All cache tests pass on Redis backend |
| 2 | Deploy two Phoenix instances on Fly; hit stock overview on instance A | Cache populated |
| 3 | Hit same stock overview on instance B | Cache hit (no external API call) |
| 4 | Remove REDIS_URL config; restart | App starts with ETS fallback |

---

## M8-002: Web performance optimization

### Ticket
**ID**: M8-002  
**Title**: Web performance optimization (Next.js)

### Description (why this ticket is needed)
The PRD targets < 2s page load. As features have been added across M2–M7, bundle size and render paths may have grown. This ticket audits and optimizes: proper RSC/client component boundaries, code splitting, lazy-loaded tabs, image optimization, and Suspense boundaries for progressive loading.

### Required tasks
- [ ] Audit client vs server component boundaries: move data-fetching-only components to RSC where possible; reduce `'use client'` surface.
- [ ] Add dynamic imports (`next/dynamic`) for heavy components: chart libraries, institutional data tables, trade modal.
- [ ] Add `<Suspense>` boundaries with skeleton fallbacks for each stock tab and portfolio sections.
- [ ] Use `next/image` for any images (stock logos, avatars); configure remote image domains.
- [ ] Analyze bundle with `@next/bundle-analyzer`; remove unused dependencies.
- [ ] Add `loading.tsx` files for route-level loading states.
- [ ] Verify Lighthouse score: target 90+ on Performance.
- [ ] Add `Cache-Control` headers for static assets and API responses where appropriate.

### Acceptance criteria
- Stock detail page loads in < 2s on a simulated 4G connection (Lighthouse or WebPageTest).
- Lighthouse Performance score >= 90.
- Tabs lazy-load their content; switching tabs shows skeleton then data.
- No layout shift on load (CLS < 0.1).

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Run Lighthouse on /stocks/AAPL | Performance score >= 90 |
| 2 | Throttle to Slow 4G; load stock page | Renders within 2s; skeletons visible during load |
| 3 | Switch between tabs | Skeleton → data; no full page reload |
| 4 | Run `npx @next/bundle-analyzer` | No unexpected large dependencies |

---

## M8-003: SEO and metadata (web)

### Ticket
**ID**: M8-003  
**Title**: SEO and metadata — web (Next.js)

### Description (why this ticket is needed)
Public share pages and stock pages should be indexable by search engines. Proper Open Graph tags make shared links look professional on social media and messaging apps. Next.js metadata API provides a clean way to set per-page titles, descriptions, and OG images.

### Required tasks
- [ ] Add `metadata` export or `generateMetadata` to stock detail page: title "AAPL Stock Analysis — MNML Trade", description with current price/recommendation, OG image (generic or dynamic).
- [ ] Add metadata to share pages: title includes ticker or portfolio name; description with recommendation or performance summary.
- [ ] Add root metadata: app name, default description, favicon, theme color.
- [ ] Add `robots.txt` and `sitemap.xml` (or `next-sitemap` package) for public routes.
- [ ] Test OG tags with social media debuggers (e.g. Facebook, Twitter/X card validator).

### Acceptance criteria
- Stock page has unique title and description in `<head>`.
- Sharing a link on social media shows rich preview (title, description, image).
- Public share pages are indexable; authenticated pages are not.
- `robots.txt` exists and is correct.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | View page source of /stocks/AAPL | `<title>`, `<meta name="description">`, `<meta property="og:...">` present |
| 2 | Paste share link into Twitter/Slack | Rich preview with title and description |
| 3 | Check /robots.txt | Valid file, disallows authenticated routes if needed |
| 4 | Verify /share/[id] pages are indexable | No `noindex` meta tag |

---

## M8-004: Error boundaries and error pages (web)

### Ticket
**ID**: M8-004  
**Title**: Error boundaries and error pages — web (Next.js)

### Description (why this ticket is needed)
Unhandled errors should not crash the entire page. Next.js `error.tsx` files catch per-route errors and show a user-friendly fallback with a retry option. A global 404 page handles invalid routes. These are essential for production quality.

### Required tasks
- [ ] Add `error.tsx` to key route groups: `stocks/[ticker]`, `portfolio`, `watchlist`, `share/[id]`. Show friendly message and "Try again" button that resets the error boundary.
- [ ] Add `not-found.tsx` for root and `stocks/[ticker]` (for invalid tickers).
- [ ] Add global `error.tsx` at `app/error.tsx` as a fallback.
- [ ] Ensure no stack traces or internal details are shown in production.
- [ ] Add toast notifications (e.g. via Sonner or react-hot-toast) for non-fatal errors (API timeout, network issue).

### Acceptance criteria
- Navigating to /stocks/INVALIDXYZ shows custom 404 page.
- If stock API fails, error boundary catches and shows friendly message with retry.
- No stack traces visible in production.
- Toast notifications for transient errors.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Navigate to /stocks/XYZNOTREAL | Custom 404 page |
| 2 | Navigate to /nonexistentroute | Global 404 page |
| 3 | Simulate API failure on stock page (e.g. disconnect API) | Error boundary with "Something went wrong" and retry button |
| 4 | Click retry | Page re-renders; if API is back, data loads |

---

## M8-005: Mobile — app store assets and configuration

### Ticket
**ID**: M8-005  
**Title**: Mobile — app icon, splash screen, store assets, and app config

### Description (why this ticket is needed)
Before submitting to the App Store and Google Play, the app needs a polished icon, splash screen, store screenshots, descriptions, and correct `app.json` / EAS configuration. These assets are the first thing users see and heavily influence download decisions.

### Required tasks
- [ ] Design app icon: 1024x1024 for App Store, 512x512 for Play Store; follow platform guidelines (no transparency on iOS).
- [ ] Design splash screen: branded loading screen with logo; configure in `app.json`.
- [ ] Update `app.json`: app name, slug, version, bundleIdentifier (iOS), package (Android), orientation, icon, splash, permissions.
- [ ] Take screenshots for App Store (6.7" iPhone, 6.5", 5.5", iPad optional) and Play Store (phone, tablet optional): key screens (login, stock analysis, portfolio, watchlist).
- [ ] Write App Store and Play Store descriptions: feature highlights, keywords.
- [ ] Add privacy policy and terms of service pages/links (required by both stores).
- [ ] Configure `eas.json` production build profile: distribution "store", auto-increment version.

### Acceptance criteria
- App icon renders correctly on iOS and Android home screens.
- Splash screen displays on cold start.
- Screenshots capture all key flows.
- Descriptions and keywords are complete.
- Privacy policy URL is live.
- `eas.json` production profile is configured.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Build dev app; check icon on home screen | Correct icon, no cropping |
| 2 | Cold-start the app | Splash screen visible briefly |
| 3 | Review screenshots against store requirements | Correct dimensions and content |
| 4 | Open privacy policy URL | Page loads with policy text |
| 5 | Run `eas build --profile production --platform all --dry-run` (or validate config) | Config is valid |

---

## M8-006: Mobile — crash reporting and analytics

### Ticket
**ID**: M8-006  
**Title**: Mobile — crash reporting (Sentry) and analytics

### Description (why this ticket is needed)
Once the app is in users' hands, crashes need to be detected and diagnosed. Sentry captures native and JS crashes with stack traces. Basic analytics (screen views, feature usage) inform product decisions. Both are essential for a production mobile app.

### Required tasks
- [ ] Add `sentry-expo` (or `@sentry/react-native`); configure DSN via env.
- [ ] Initialize Sentry in root layout; capture unhandled JS errors and native crashes.
- [ ] Verify source maps are uploaded on EAS build so stack traces are readable.
- [ ] Add basic analytics: integrate Expo Analytics, Mixpanel, or a lightweight solution. Track events: `screen_view`, `stock_search`, `stock_view`, `trade_executed`, `watchlist_add`.
- [ ] Add analytics opt-out toggle in profile/settings (GDPR-friendly).

### Acceptance criteria
- A forced crash (e.g. throw in a component) appears in Sentry dashboard with readable stack trace.
- Key events are tracked in the analytics platform.
- Users can opt out of analytics.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Trigger an intentional crash in dev build | Error appears in Sentry dashboard |
| 2 | Verify stack trace has readable function names (source maps) | Readable, not minified |
| 3 | Open stock detail; check analytics dashboard | `stock_view` event logged |
| 4 | Execute a trade; check analytics | `trade_executed` event logged |
| 5 | Toggle analytics off in settings; perform actions | No new events tracked |

---

## M8-007: Mobile — App Store and Play Store submission

### Ticket
**ID**: M8-007  
**Title**: Mobile — App Store and Google Play submission

### Description (why this ticket is needed)
This is the final step to get the app into users' hands via official stores. It involves building production binaries via EAS, submitting to Apple and Google for review, responding to any review feedback, and verifying the live listing. Beta testing via TestFlight / Internal Testing is done first.

### Required tasks
- [ ] **Beta**: run `eas build --profile production --platform ios`; submit to TestFlight via `eas submit --platform ios`; invite 5–10 beta testers. Same for Android Internal Testing track.
- [ ] Collect and address beta feedback (bug fixes, UI tweaks).
- [ ] **Production submit**: after beta is stable, submit iOS build for App Store review; submit Android build for Play Store review.
- [ ] Monitor review status; respond to any rejection feedback (common: missing permissions justification, privacy policy issues, crash on review device).
- [ ] Once approved, release to public (phased or full rollout).
- [ ] Verify live store listing: correct screenshots, description, icon, link to privacy policy.
- [ ] Configure OTA updates: verify `eas update --branch production` delivers an update to installed apps.

### Acceptance criteria
- iOS app approved and live on App Store.
- Android app approved and live on Google Play.
- Store listings match designed assets and descriptions.
- OTA update mechanism works (push an update; installed app picks it up).

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Install from TestFlight (iOS); run through key flows | All features work; no crashes |
| 2 | Install from Internal Testing (Android); run through key flows | All features work |
| 3 | After store approval, download from App Store | App installs and runs correctly |
| 4 | After store approval, download from Play Store | App installs and runs correctly |
| 5 | Push OTA update via `eas update`; reopen installed app | Update applied; new behavior visible |

---

## M8-008: Observability — monitoring and health

### Ticket
**ID**: M8-008  
**Title**: Observability — monitoring, metrics, and alerts

### Description (why this ticket is needed)
In production, you need visibility into API health, latency, error rates, cache hit rates, and external API usage. Without monitoring, problems go undetected until users complain. This ticket adds structured logging, key metrics, and basic alerting.

### Required tasks
- [ ] **Structured logging**: ensure all Phoenix requests log request_id, user_id (if auth), path, status, and duration. Use Logger with JSON formatter for production.
- [ ] **Health endpoint improvements**: `/api/health` checks DB and optionally Redis; returns service versions, uptime.
- [ ] **Metrics** (choose approach: Telemetry + Prometheus, or Fly.io built-in metrics, or StatsD):
  - Request count and latency by route and status code.
  - Cache hit/miss rate by data type.
  - External API call count and error rate per provider.
  - Oban job count, success/failure rate.
- [ ] **Alerting**: set up basic alerts (e.g. Fly.io alerts, or UptimeRobot/Better Uptime) for health endpoint down, high error rate, or high latency.
- [ ] **Web analytics**: add Plausible or Umami (privacy-focused) to Next.js for page views and feature usage.
- [ ] Phoenix LiveDashboard: enable in production (behind auth) for real-time system inspection.

### Acceptance criteria
- Structured logs are queryable (e.g. by request_id or user_id).
- Key metrics are being collected (viewable in dashboard or logs).
- Health endpoint responds and is monitored; alert fires if it goes down.
- Web analytics tracking page views.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Make API requests; check logs | Structured JSON with request_id, path, status, duration |
| 2 | Check cache hit rate metric after repeated stock requests | Hit rate > 0% |
| 3 | Stop Phoenix; verify alert fires (or simulate) | Alert notification received |
| 4 | Access Phoenix LiveDashboard at /dashboard (auth'd) | Dashboard loads with system info |
| 5 | Check web analytics for page views | Recent views recorded |

---

## M8-009: Oban tuning and job reliability

### Ticket
**ID**: M8-009  
**Title**: Oban tuning and job reliability

### Description (why this ticket is needed)
As user count grows and more watchlist tickers need refreshing, Oban job volume increases. This ticket tunes concurrency, retry policies, and scheduling to maximize cache freshness while staying within rate limits and not overloading the database with job rows.

### Required tasks
- [ ] Review and tune Oban queue concurrency per queue (e.g. `:data_refresh` max 5, `:notifications` max 10) based on external API rate limits.
- [ ] Configure retry policies: max attempts per worker, backoff strategy (exponential).
- [ ] Add job pruning: configure Oban Pruner to remove completed/discarded jobs after N days (e.g. 7 days) to keep the `oban_jobs` table small.
- [ ] Add unique job constraints where appropriate (e.g. only one RefreshStockData for AAPL at a time).
- [ ] Verify job scheduling during market hours vs off-hours: more frequent during market hours.
- [ ] Add error reporting: failed jobs logged with reason; optionally reported to Sentry.

### Acceptance criteria
- No duplicate concurrent jobs for the same ticker.
- Failed jobs retry with backoff and eventually stop after max attempts.
- Completed jobs are pruned after configured retention period.
- Rate limits are not exceeded by job throughput.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Enqueue two RefreshStockData jobs for same ticker simultaneously | Only one executes (unique constraint) |
| 2 | Force a job to fail; check retries | Retries with increasing delay; stops at max attempts |
| 3 | Check `oban_jobs` table after 7+ days | Old completed jobs pruned |
| 4 | Monitor external API calls during peak job run | Calls within rate limit |

---

## M8-010: Advanced features (optional scope)

### Ticket
**ID**: M8-010  
**Title**: Advanced features — leaderboard, multiple portfolios, CSV export

### Description (why this ticket is needed)
These are PRD Phase 4 enhancements that add engagement and utility: a friends leaderboard for paper trading, support for multiple portfolios, and data export (CSV for transactions, optionally PDF for portfolio reports). Each is independently scoped and can be implemented as time permits.

### Required tasks
- [ ] **Multiple portfolios**: remove single-portfolio constraint; allow users to create N portfolios; add portfolio selector dropdown in web and mobile; update trade flow to select target portfolio.
- [ ] **Leaderboard** (Phase 2, opt-in): create `GET /api/paper-trading/leaderboard` endpoint; rank users by total return %, win rate; friends only (if social graph exists) or global; add leaderboard UI on web and mobile.
- [ ] **CSV export**: add `GET /api/paper-trading/portfolios/:id/transactions/export?format=csv` endpoint; generate CSV file; add "Export CSV" button on web transaction history page.
- [ ] **PDF report** (optional): generate portfolio summary PDF server-side; downloadable from web.
- [ ] **Achievements** (optional): track milestones (first trade, 10 trades, profit milestone); display badges on profile.

### Acceptance criteria
- Multiple portfolios: user can create, switch between, and trade in multiple portfolios.
- Leaderboard: ranked list of users by performance (opt-in only).
- CSV export: downloads a valid CSV file with all transactions.
- Each feature works independently; none blocks the others.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Create 3 portfolios; trade in each | All portfolios track independently |
| 2 | View leaderboard | Ranked list of users (or friends) |
| 3 | Click "Export CSV" on transaction history | CSV downloads with correct data |
| 4 | Open CSV in spreadsheet app | Columns and data match transaction history |

---

## Milestone 8 completion checklist

- [ ] M8-001: Redis cache (if multi-node)
- [ ] M8-002: Web performance optimization
- [ ] M8-003: SEO and metadata
- [ ] M8-004: Error boundaries and error pages
- [ ] M8-005: Mobile — store assets and config
- [ ] M8-006: Mobile — crash reporting and analytics
- [ ] M8-007: Mobile — App Store and Play Store submission
- [ ] M8-008: Observability — monitoring and health
- [ ] M8-009: Oban tuning and job reliability
- [ ] M8-010: Advanced features (optional)

**Done when**: Web meets performance and SEO targets; mobile apps are live on App Store and Google Play with crash reporting and analytics; monitoring is active with alerting; cache and Oban are tuned for production traffic; optional advanced features shipped as scoped.

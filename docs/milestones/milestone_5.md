# Milestone 5 — Engagement & Sharing: Tickets

**Goal**: Watchlist, analysis history, shareable links, push notifications, and background data refresh.  
**Dependencies**: M2 (stocks/cache), M3 (full analysis), M4 (paper trading for portfolio share).  
**HLD reference**: §12.5 Logical Milestones — Milestone 5.

---

## M5-001: Watchlist database schema and context

### Ticket
**ID**: M5-001  
**Title**: Watchlist database schema and context

### Description (why this ticket is needed)
Users want to save stocks they follow so they can quickly return to them. The Watchlist context provides add, remove, and list operations scoped to the authenticated user. The database table enforces a unique constraint per user + ticker to prevent duplicates.

### Required tasks
- [ ] Create Ecto schema and migration for `watchlists`: `user_id` (references users), `ticker` (string), `added_at` (utc_datetime), timestamps. Unique index on `(user_id, ticker)`. Index on `user_id`.
- [ ] Create `StockAnalysis.Watchlist` context module.
- [ ] Implement `add(user_id, ticker)`: insert or return existing; validate ticker is non-empty.
- [ ] Implement `remove(user_id, ticker)`: delete row; return `{:ok, :removed}` or `{:error, :not_found}`.
- [ ] Implement `list(user_id)`: return all watchlist entries for user, ordered by `added_at DESC`.
- [ ] Expose endpoints:
  - `GET /api/user/watchlist` — list
  - `POST /api/user/watchlist` — add (body: `{ticker}`)
  - `DELETE /api/user/watchlist/:ticker` — remove
- [ ] Add `WatchlistItem` type and api-client methods.

### Acceptance criteria
- User can add a ticker; duplicate add is idempotent (no error, returns existing).
- User can remove a ticker; removing a non-existent ticker returns 404.
- List returns all watchlist tickers for the user.
- Scoped to authenticated user only.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | POST /api/user/watchlist `{ticker: "AAPL"}` | 201, watchlist item |
| 2 | POST same ticker again | 200 or 201, no duplicate |
| 3 | GET /api/user/watchlist | Array containing AAPL |
| 4 | DELETE /api/user/watchlist/AAPL | 200 or 204 |
| 5 | GET /api/user/watchlist | Empty array |
| 6 | DELETE /api/user/watchlist/AAPL again | 404 |

---

## M5-002: Analysis history

### Ticket
**ID**: M5-002  
**Title**: Analysis history — track and list recently viewed stocks

### Description (why this ticket is needed)
Users benefit from seeing which stocks they recently analyzed so they can quickly revisit them. The history is recorded automatically when a stock overview is viewed and capped at the last 20 entries per user. This also feeds future analytics (most viewed stocks, engagement metrics).

### Required tasks
- [ ] Create Ecto schema and migration for `analysis_history`: `user_id` (references users), `ticker` (string), `viewed_at` (utc_datetime), timestamps. Index on `(user_id, viewed_at DESC)`.
- [ ] Implement `record_view(user_id, ticker)` in Watchlist context (or a dedicated History sub-module): insert new entry; prune entries beyond 20 per user (delete oldest).
- [ ] Implement `list_history(user_id, limit \\ 20)`: return recent entries ordered by `viewed_at DESC`.
- [ ] Hook into the stock overview controller: after successful `GET /api/stocks/:ticker`, call `record_view` asynchronously (e.g. `Task.start` or Oban job) so it doesn't add latency.
- [ ] Expose endpoint: `GET /api/user/history` — list recent views.
- [ ] Add type and api-client method.

### Acceptance criteria
- Viewing a stock overview automatically records history.
- History returns up to 20 most recent entries, newest first.
- Viewing the same ticker updates `viewed_at` (or adds a new row — either approach is acceptable).
- Recording does not add latency to the stock overview response.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | GET /api/stocks/AAPL, then GET /api/user/history | History contains AAPL |
| 2 | View 5 different stocks; GET history | All 5 present, ordered by most recent |
| 3 | View 25 different stocks; GET history | Only 20 most recent returned |
| 4 | View AAPL again after viewing others | AAPL moves to top of history |

---

## M5-003: Shareable links — backend

### Ticket
**ID**: M5-003  
**Title**: Shareable links — backend (Shares context)

### Description (why this ticket is needed)
Users want to share a stock analysis or portfolio snapshot with friends via a unique URL. The Shares context generates a short, unguessable link ID, stores the payload (or a reference to it), and serves it publicly without authentication. This drives word-of-mouth growth.

### Required tasks
- [ ] Create Ecto schema and migration for `shares`: `id` (string, primary key — short random ID e.g. nanoid 10 chars), `payload_type` (string: "analysis" or "portfolio"), `payload` (map/jsonb — snapshot of data at share time or reference), `user_id` (references users, nullable), `expires_at` (utc_datetime, nullable), timestamps.
- [ ] Create `StockAnalysis.Shares` context module.
- [ ] Implement `create_share(user_id, %{type, payload_ref})`:
  - For analysis: snapshot current recommendation, scores, and ticker.
  - For portfolio: snapshot holdings, performance metrics, portfolio value (no transaction history for privacy).
  - Generate short ID; insert row.
- [ ] Implement `get_share(share_id)`: return payload; 404 if not found or expired.
- [ ] Expose endpoints:
  - `POST /api/shares/create` (auth required) — body: `{type: "analysis"|"portfolio", ref: ticker|portfolio_id}`
  - `GET /api/shares/:id` (public, no auth) — returns share payload
- [ ] For paper trading, add `POST /api/paper-trading/portfolios/:id/share` as convenience that calls Shares context.
- [ ] Add types and api-client methods.

### Acceptance criteria
- Creating a share returns a short ID.
- GET share by ID returns the payload without authentication.
- Portfolio share includes holdings and performance but not transaction history.
- Invalid/expired share ID returns 404.
- Share ID is unguessable (random, not sequential).

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | POST /api/shares/create `{type: "analysis", ref: "AAPL"}` | 201, `{id: "abc123xyz"}` |
| 2 | GET /api/shares/abc123xyz (no auth) | 200, analysis snapshot payload |
| 3 | POST portfolio share | 201, share ID |
| 4 | GET portfolio share (no auth) | 200, holdings and performance (no transactions) |
| 5 | GET /api/shares/nonexistent | 404 |

---

## M5-004: Shareable links — web UI

### Ticket
**ID**: M5-004  
**Title**: Shareable links — web UI (share button and public view)

### Description (why this ticket is needed)
Users need a "Share" button on stock pages and portfolio pages that generates a link they can copy. When someone opens that link, they see a public read-only view of the analysis or portfolio snapshot — this is the viral loop for user acquisition.

### Required tasks
- [ ] Add "Share" button on stock detail page (near recommendation badge).
- [ ] Add "Share" button on portfolio dashboard.
- [ ] On click: call `api.createShare(...)`, receive short ID, construct URL (e.g. `https://app.com/share/abc123xyz`), copy to clipboard with toast confirmation ("Link copied!").
- [ ] Create public share page: `/share/[id]/page.tsx` — fetches `api.getShare(id)` (no auth).
  - Analysis share: display recommendation, scores, ticker, price at share time.
  - Portfolio share: display holdings table, total value, return %, top performers.
  - "Sign up to create your own" CTA.
- [ ] Handle 404 (invalid share link): friendly "Link not found" page.

### Acceptance criteria
- Share button generates link and copies to clipboard.
- Public share page loads without login and shows correct data.
- CTA links to register page.
- 404 for invalid links.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | On /stocks/AAPL, click Share | Link copied toast; link in clipboard |
| 2 | Open link in incognito (no auth) | Public analysis view loads |
| 3 | On portfolio page, click Share | Link copied |
| 4 | Open portfolio share link incognito | Holdings and performance visible; no transactions |
| 5 | Open invalid share link | "Link not found" page |

---

## M5-005: Watchlist and history UI (web)

### Ticket
**ID**: M5-005  
**Title**: Watchlist and history UI — web (Next.js)

### Description (why this ticket is needed)
Users need a dedicated watchlist page and easy access to recently viewed stocks. The watchlist page shows saved tickers with current price and quick actions. Add/remove buttons on stock pages let users manage their watchlist inline.

### Required tasks
- [ ] Create `/watchlist/page.tsx`: fetch `api.getWatchlist()` via React Query; display list of tickers with name, current price (from stock overview), change (colored), and "Remove" button.
- [ ] Add "Watchlist" link to top navbar.
- [ ] On stock detail page, add "Add to Watchlist" / "Remove from Watchlist" toggle button (heart icon or star). Optimistic update via React Query mutation.
- [ ] Add "Recent" section (sidebar, dropdown, or on watchlist page): fetch `api.getHistory()`; show last 5–10 tickers as links.
- [ ] Empty state for watchlist ("Add stocks to your watchlist from any analysis page").

### Acceptance criteria
- Watchlist page shows saved tickers with prices.
- Add/remove on stock page updates watchlist immediately (optimistic).
- Recent history shows last viewed tickers.
- Removing from watchlist page updates list.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | On /stocks/AAPL, click "Add to Watchlist" | Button toggles to "Remove"; toast confirms |
| 2 | Navigate to /watchlist | AAPL listed with price |
| 3 | Click "Remove" on watchlist page | AAPL removed from list |
| 4 | View several stocks; check recent section | Recent tickers shown |
| 5 | Watchlist with no items | Empty state displayed |

---

## M5-006: Watchlist, history, and share — mobile (Expo)

### Ticket
**ID**: M5-006  
**Title**: Watchlist, history, and share — mobile (Expo)

### Description (why this ticket is needed)
Mobile users need the same watchlist management, history, and share capabilities as web, adapted for native UI patterns (bottom tab, swipe-to-delete, native share sheet).

### Required tasks
- [ ] **Watchlist tab**: activate in tab navigator. Fetch watchlist; display FlatList of tickers with price, change, and swipe-to-remove gesture. Tap row → navigate to stock detail.
- [ ] On stock detail screen, add "Add to Watchlist" / "Remove" button (icon).
- [ ] **History**: show recent stocks on Home tab (e.g. horizontal scroll of recent tickers above trending section).
- [ ] **Share**: on stock detail and portfolio screens, add Share button. On press: create share link via API, then open native share sheet (React Native Share API) with the URL.
- [ ] Pull-to-refresh on watchlist.

### Acceptance criteria
- Watchlist tab shows saved tickers; add/remove works from stock detail.
- History shows recent tickers on Home.
- Share opens native share sheet with generated link.
- Watchlist refreshes on pull.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Tap "Add to Watchlist" on stock detail | Icon toggles; watchlist tab shows ticker |
| 2 | Swipe-to-remove on watchlist | Ticker removed |
| 3 | Check Home tab | Recent tickers visible |
| 4 | Tap Share on stock detail | Native share sheet opens with link |
| 5 | Pull-to-refresh watchlist | Data reloads |

---

## M5-007: Oban background data refresh jobs

### Ticket
**ID**: M5-007  
**Title**: Oban background data refresh jobs

### Description (why this ticket is needed)
Cache entries expire on TTL; without background refresh, the first user to request after expiry pays the full latency of external API calls. Oban jobs proactively refresh cache for high-priority tickers (watchlist aggregates, trending) so that most requests are cache hits. This also respects rate limits by spreading calls over time.

### Required tasks
- [ ] Add Oban dependency and configure in Phoenix application (queue: `:data_refresh`, max concurrency based on rate limits).
- [ ] Create `StockAnalysis.Workers.RefreshStockData` Oban worker: accepts a ticker; refreshes price, technical, fundamental, sentiment, and institutional data by calling the respective contexts (which will hit external APIs and update cache).
- [ ] Create `StockAnalysis.Workers.ScheduleRefresh` Oban worker (cron or periodic): queries for high-priority tickers (union of all user watchlists, plus trending); enqueues `RefreshStockData` for each, staggered to stay within rate limits.
- [ ] Respect rate limits: track calls per provider; skip or delay if approaching limit.
- [ ] Add Oban dashboard or logging for monitoring job status and failures.
- [ ] Configure schedule: e.g. every 30min during market hours, every 2h off-hours.

### Acceptance criteria
- Oban starts with the application; jobs are persisted in PostgreSQL.
- Refresh jobs run on schedule; cache entries are updated before TTL expiry for priority tickers.
- Rate limits are not exceeded; jobs back off when approaching limits.
- Failed jobs retry with backoff (Oban default behavior).

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Add AAPL to watchlist; wait for next refresh cycle | Cache for AAPL is fresh (verify via cache inspection or logs) |
| 2 | Check Oban job logs | RefreshStockData jobs completed for watchlist tickers |
| 3 | Simulate rate limit approach | Jobs skip or delay; no 429 errors from external APIs |
| 4 | Kill and restart Phoenix | Oban resumes pending jobs from DB |

---

## M5-008: Push notifications (mobile)

### Ticket
**ID**: M5-008  
**Title**: Push notifications — Expo Push

### Description (why this ticket is needed)
Push notifications re-engage mobile users by alerting them to events they care about — price movement on watchlist stocks or unusual whale activity. This ticket sets up the infrastructure: device token registration, backend notification sending via Expo Push API, and basic alert types.

### Required tasks
- [ ] **Mobile**: integrate `expo-notifications`; on login or app startup, request push permission; retrieve Expo Push Token; send to backend via `POST /api/user/push-token` (body: `{token, platform}`).
- [ ] **API**: create endpoint `POST /api/user/push-token` to store push token per user (new table or column on users). Create endpoint `PUT /api/user/notification-preferences` for enabling/disabling alert types.
- [ ] **Backend push module**: create `StockAnalysis.Notifications` module; implement `send_push(user_id, title, body, data)` that looks up the user's push token and calls Expo Push API (`https://exp.host/--/api/v2/push/send`).
- [ ] **Oban worker for alerts**: create `StockAnalysis.Workers.CheckAlerts` that runs periodically; for each watchlist ticker, check if price crossed a threshold or unusual whale activity detected since last check; if so, enqueue push via Notifications module.
- [ ] **Mobile**: handle received notification (foreground banner, tap → navigate to stock detail).
- [ ] Add notification preferences screen/section on mobile (toggle push on/off, toggle alert types).

### Acceptance criteria
- Mobile app registers push token with backend on login.
- Backend can send a push notification that arrives on the device.
- Notification tap opens the app and navigates to relevant stock.
- Users can toggle notifications on/off.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Log in on mobile; check backend DB for push token | Token stored for user |
| 2 | Trigger a test push from backend (e.g. via IEx or admin endpoint) | Notification appears on device |
| 3 | Tap the notification | App opens to relevant screen |
| 4 | Disable notifications in preferences; trigger push | No notification received |
| 5 | Log out; verify token is cleared or invalidated | Token removed |

---

## M5-009: User profile page (web)

### Ticket
**ID**: M5-009  
**Title**: User profile page — web (Next.js)

### Description (why this ticket is needed)
Users need a place to view and manage their account: username, email, notification preferences, and logout. The profile page centralizes account settings and provides a clean logout flow.

### Required tasks
- [ ] Create `/profile/page.tsx`: display current user info (email, username, avatar placeholder).
- [ ] Add edit form for username (call `PUT /api/user/profile`).
- [ ] Add notification preferences section (email/push toggles — mobile push is managed on device, but web preferences can be stored).
- [ ] Add "Logout" button; clear token and redirect to login.
- [ ] Add profile link to navbar dropdown (avatar or username).

### Acceptance criteria
- Profile page shows user info.
- Username is editable.
- Logout clears session and redirects to login.
- Accessible from navbar.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Navigate to /profile | Email and username visible |
| 2 | Edit username; save | Updated; API call succeeds |
| 3 | Click Logout | Redirect to login; token cleared |
| 4 | Try to access /profile again | Redirect to login |

---

## M5-010: Deployment pipeline (Fly.io, Vercel, EAS)

### Ticket
**ID**: M5-010  
**Title**: Deployment pipeline (Fly.io, Vercel, EAS)

### Description (why this ticket is needed)
To validate the full stack and allow testing from real devices and shared URLs, the API and web app must deploy to production-like environments, and the mobile app must be buildable and testable via EAS. Wiring secrets and environment variables correctly ensures that auth and CORS work in production. Deferred from M1 so that deployment includes the stock analysis features built in M2, making the first deploy more meaningful.

### Required tasks
- [ ] **Phoenix on Fly.io**: Create Fly app (or use existing); attach or create Postgres; set secrets (e.g. `SECRET_KEY_BASE`, `DATABASE_URL`, `ALPHA_VANTAGE_API_KEY`, `UNUSUAL_WHALES_API_KEY`). Configure `mix release` and `fly deploy`; run migrations as part of deploy or via release command. Document deploy steps.
- [ ] **Next.js on Vercel**: Connect repo (or manual deploy); set build output to `apps/web` (or root with turbo filter). Set env: `NEXT_PUBLIC_API_URL` to Phoenix URL (e.g. `https://<app>.fly.dev`). Ensure CORS on Phoenix allows Vercel origin and preview URLs.
- [ ] **EAS for mobile**: Create EAS project; configure `app.json`/`eas.json` (e.g. development build profile). Set `EXPO_PUBLIC_API_URL` in EAS env or app config to production API URL for dev builds. Document how to run `eas build --profile development` and install on device/simulator.
- [ ] Update API CORS config with production web URL and any Expo/redirect URIs if needed.
- [ ] Add a brief "Deployment" section to README or docs: how to deploy API, web, and how to build mobile for testing.

### Acceptance criteria
- Phoenix deploys to Fly.io; health endpoint returns 200 in production; DB migrations applied.
- Next.js deploys to Vercel; production URL loads; login/register work against production API (CORS allows origin).
- EAS build (development profile) produces an installable binary; app can point to production API and complete login flow.
- No secrets (API keys, DB URLs) are committed; all sensitive config via Fly/Vercel/EAS secrets or env.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Deploy Phoenix; open `https://<app>.fly.dev/api/health` | 200, JSON status |
| 2 | Deploy Next.js; open production URL | App loads; login form visible |
| 3 | Log in on production web app | Success; token stored; protected page visible |
| 4 | Run EAS build for development; install on device | App launches; can set API URL to production and log in |
| 5 | Verify CORS: from production web origin, POST to API login | 200 and CORS headers present |
| 6 | Confirm no secrets in repo (e.g. grep or audit) | No SECRET_KEY_BASE, DATABASE_URL, etc. in committed files |

---

## Milestone 5 completion checklist

- [ ] M5-001: Watchlist schema and context
- [ ] M5-002: Analysis history
- [ ] M5-003: Shareable links — backend
- [ ] M5-004: Shareable links — web UI
- [ ] M5-005: Watchlist and history UI (web)
- [ ] M5-006: Watchlist, history, share (mobile)
- [ ] M5-007: Oban background refresh jobs
- [ ] M5-008: Push notifications (mobile)
- [ ] M5-009: User profile page (web)
- [ ] M5-010: Deployment pipeline (Fly.io, Vercel, EAS)

**Done when**: Users can manage a watchlist, see analysis history, share stock analyses and portfolio snapshots via public links, receive push notifications on mobile, and background jobs keep cache fresh for priority tickers; deployment pipeline (Fly, Vercel, EAS) is in place when ready.

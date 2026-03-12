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
- [x] Create Ecto schema and migration for `watchlists`: `user_id` (references users), `ticker` (string), `added_at` (utc_datetime), timestamps. Unique index on `(user_id, ticker)`. Index on `user_id`.
- [x] Create `StockAnalysis.Watchlist` context module.
- [x] Implement `add(user_id, ticker)`: insert or return existing; validate ticker is non-empty.
- [x] Implement `remove(user_id, ticker)`: delete row; return `{:ok, :removed}` or `{:error, :not_found}`.
- [x] Implement `list(user_id)`: return all watchlist entries for user, ordered by `added_at DESC`.
- [x] Expose endpoints:
  - `GET /api/user/watchlist` — list
  - `POST /api/user/watchlist` — add (body: `{ticker}`)
  - `DELETE /api/user/watchlist/:ticker` — remove
- [x] Add `WatchlistItem` type and api-client methods.

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
- [x] Create Ecto schema and migration for `analysis_history`: `user_id` (references users), `ticker` (string), `viewed_at` (utc_datetime), timestamps. Index on `(user_id, viewed_at DESC)`.
- [x] Implement `record_view(user_id, ticker)` in Watchlist context (or a dedicated History sub-module): insert new entry; prune entries beyond 20 per user (delete oldest).
- [x] Implement `list_history(user_id, limit \\ 20)`: return recent entries ordered by `viewed_at DESC`.
- [x] Hook into the stock overview controller: after successful `GET /api/stocks/:ticker`, call `record_view` asynchronously (e.g. `Task.start` or Oban job) so it doesn't add latency.
- [x] Expose endpoint: `GET /api/user/history` — list recent views.
- [x] Add type and api-client method.

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

## M5-003: Watchlist and history UI (web)

### Ticket
**ID**: M5-003  
**Title**: Watchlist and history UI — web (Next.js)

### Description (why this ticket is needed)
Users need a dedicated watchlist page and easy access to recently viewed stocks. The watchlist page shows saved tickers with current price and quick actions. Add/remove buttons on stock pages let users manage their watchlist inline.

### Required tasks
- [x] Create `/watchlist/page.tsx`: fetch `api.getWatchlist()` via React Query; display list of tickers with name, current price (from stock overview), change (colored), and "Remove" button.
- [x] Add "Watchlist" link to top navbar.
- [x] On stock detail page, add "Add to Watchlist" / "Remove from Watchlist" toggle button (heart icon or star). Optimistic update via React Query mutation.
- [x] Add "Recent" section (sidebar, dropdown, or on watchlist page): fetch `api.getHistory()`; show last 5–10 tickers as links.
- [x] Empty state for watchlist ("Add stocks to your watchlist from any analysis page").

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

## M5-004: Watchlist and history — mobile (Expo)

### Ticket
**ID**: M5-004  
**Title**: Watchlist and history — mobile (Expo)

### Description (why this ticket is needed)
Mobile users need the same watchlist management and history capabilities as web, adapted for native UI patterns (bottom tab, swipe-to-delete).

### Required tasks
- [x] **Watchlist tab**: activate in tab navigator. Fetch watchlist; display FlatList of tickers with price, change, and swipe-to-remove gesture. Tap row → navigate to stock detail.
- [x] On stock detail screen, add "Add to Watchlist" / "Remove" button (icon).
- [x] **History**: show recent stocks on Home tab (e.g. horizontal scroll of recent tickers above trending section).
- [x] Pull-to-refresh on watchlist.

### Acceptance criteria
- Watchlist tab shows saved tickers; add/remove works from stock detail.
- History shows recent tickers on Home.
- Watchlist refreshes on pull.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Tap "Add to Watchlist" on stock detail | Icon toggles; watchlist tab shows ticker |
| 2 | Swipe-to-remove on watchlist | Ticker removed |
| 3 | Check Home tab | Recent tickers visible |
| 4 | Pull-to-refresh watchlist | Data reloads |

---

## M5-005: Oban background data refresh jobs

### Ticket
**ID**: M5-005  
**Title**: Oban background data refresh jobs

### Description (why this ticket is needed)
Cache entries expire on TTL; without background refresh, the first user to request after expiry pays the full latency of external API calls. Oban jobs proactively refresh cache for high-priority tickers (watchlist aggregates, trending) so that most requests are cache hits. This also respects rate limits by spreading calls over time.

### Required tasks
- [x] Add Oban dependency and configure in Phoenix application (queue: `:data_refresh`, max concurrency based on rate limits).
- [x] Create `StockAnalysis.Workers.RefreshStockData` Oban worker: accepts a ticker; refreshes price, technical, fundamental, sentiment, and institutional data by calling the respective contexts (which will hit external APIs and update cache).
- [x] Create `StockAnalysis.Workers.ScheduleRefresh` Oban worker (cron or periodic): queries for high-priority tickers (union of all user watchlists, plus trending); enqueues `RefreshStockData` for each, staggered to stay within rate limits.
- [x] Respect rate limits: track calls per provider; skip or delay if approaching limit.
- [x] Add Oban dashboard or logging for monitoring job status and failures.
- [x] Configure schedule: e.g. every 30min during market hours, every 2h off-hours.

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

## M5-006: Push notifications (mobile)

### Ticket
**ID**: M5-006  
**Title**: Push notifications — Expo Push

### Description (why this ticket is needed)
Push notifications re-engage mobile users by alerting them to events they care about — price movement on watchlist stocks or unusual whale activity. This ticket sets up the infrastructure: device token registration, backend notification sending via Expo Push API, and basic alert types.

### Required tasks
- [x] **Mobile**: integrate `expo-notifications`; on login or app startup, request push permission; retrieve Expo Push Token; send to backend via `POST /api/user/push-token` (body: `{token, platform}`).
- [x] **API**: create endpoint `POST /api/user/push-token` to store push token per user (new table or column on users). Create endpoint `PUT /api/user/notification-preferences` for enabling/disabling alert types.
- [x] **Backend push module**: create `StockAnalysis.Notifications` module; implement `send_push(user_id, title, body, data)` that looks up the user's push token and calls Expo Push API (`https://exp.host/--/api/v2/push/send`).
- [x] **Oban worker for alerts**: create `StockAnalysis.Workers.CheckAlerts` that runs periodically; for each watchlist ticker, check if price crossed a threshold or unusual whale activity detected since last check; if so, enqueue push via Notifications module.
- [x] **Mobile**: handle received notification (foreground banner, tap → navigate to stock detail).
- [x] Add notification preferences screen/section on mobile (toggle push on/off, toggle alert types).

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

## M5-007: User profile page (web)

### Ticket
**ID**: M5-007  
**Title**: User profile page — web (Next.js)

### Description (why this ticket is needed)
Users need a place to view and manage their account: username, email, notification preferences, and logout. The profile page centralizes account settings and provides a clean logout flow.

### Required tasks
- [x] Create `/profile/page.tsx`: display current user info (email, username, avatar placeholder).
- [x] Add edit form for username (call `PUT /api/user/profile`).
- [x] Add notification preferences section (email/push toggles — mobile push is managed on device, but web preferences can be stored).
- [x] Add "Logout" button; clear token and redirect to login.
- [x] Add profile link to navbar dropdown (avatar or username).

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

## Milestone 5 completion checklist

- [x] M5-001: Watchlist schema and context
- [x] M5-002: Analysis history
- [x] M5-003: Watchlist and history UI (web)
- [x] M5-004: Watchlist and history (mobile)
- [x] M5-005: Oban background refresh jobs
- [x] M5-006: Push notifications (mobile)
- [x] M5-007: User profile page (web)

**Done when**: Users can manage a watchlist, see analysis history, receive push notifications on mobile, and background jobs keep cache fresh for priority tickers.

# Milestone 2 — Stock Analysis Core: Tickets

**Goal**: Technical analysis and stock overview on web and mobile; one analysis tab (Technical) and basic institutional data.  
**Dependencies**: M1 (Foundation).  
**HLD reference**: §12.2 Logical Milestones — Milestone 2.

---

## M2-001: ETS cache layer

### Ticket
**ID**: M2-001  
**Title**: ETS cache layer

### Description (why this ticket is needed)
Every external API call costs money and time; most stock data does not change every second. A cache layer in Phoenix (using ETS) lets us store responses with TTLs, serve repeat requests instantly, and stay within API rate limits. This ticket is the foundation for all stock, analysis, and institutional data fetching in M2 and beyond.

### Required tasks
- [x] Create a cache module (e.g. `StockAnalysis.Cache`) backed by ETS (or a GenServer wrapping `:ets`).
- [x] Support operations: `get(key)`, `put(key, value, ttl_seconds)`, `delete(key)`, `exists?(key)`.
- [x] Key convention: `"#{scope}:#{ticker}:#{data_type}"` (e.g. `"stocks:AAPL:price"`, `"analysis:AAPL:technical"`).
- [x] TTL enforcement: entries auto-expire; `get` returns `nil` for expired entries and cleans them up lazily or via periodic sweep.
- [x] Support configurable default TTLs per data type: price 15s, technical 1h, institutional 1h.
- [x] Start cache process in application supervision tree.
- [x] Add tests for put/get, TTL expiry, and key miss.

### Acceptance criteria
- `Cache.put("k", value, 5)` → `Cache.get("k")` returns value within 5s, returns `nil` after 5s.
- Cache starts with the application and survives across requests.
- Multiple data types can coexist without key collision.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Put a value with 2s TTL; get immediately | Returns the value |
| 2 | Wait 3s; get same key | Returns nil |
| 3 | Put two values with different keys | Both retrievable independently |
| 4 | Delete a key; get it | Returns nil |
| 5 | Run `mix test` for cache module | All tests pass |

---

## M2-002: Alpha Vantage integration module

### Ticket
**ID**: M2-002  
**Title**: Alpha Vantage integration module

### Description (why this ticket is needed)
Alpha Vantage is the primary source for real-time/historical prices and technical indicators (RSI, MACD, SMA, etc.). A dedicated integration module encapsulates API authentication, HTTP calls, error handling, and response normalization so the rest of the codebase works with clean Elixir structs rather than raw JSON.

### Required tasks
- [x] Create module `StockAnalysis.Integrations.AlphaVantage`.
- [x] Configure API key via application env / `ALPHA_VANTAGE_API_KEY` (never hard-coded).
- [x] Implement functions: `get_quote(ticker)` (current price, change, volume), `get_intraday(ticker, interval)`, `get_daily(ticker)` (historical OHLCV), `get_technical_indicator(ticker, indicator, params)` (RSI, MACD, SMA, Bollinger, ATR, ADX, Stochastic).
- [x] Normalize responses into structs or maps with consistent field names (e.g. `%{open, high, low, close, volume, timestamp}`).
- [x] Handle errors: HTTP failures, invalid ticker, rate limit (5/min free), malformed JSON. Return `{:ok, data}` or `{:error, reason}`.
- [x] Add rate-limit awareness: log warnings when approaching limit; optionally delay or queue.
- [x] Write tests with mocked HTTP responses (e.g. using `Mox` or fixture files).

### Acceptance criteria
- `AlphaVantage.get_quote("AAPL")` returns `{:ok, %{price: ..., change: ..., ...}}` with real or mocked data.
- Technical indicator calls return normalized maps.
- Invalid ticker or HTTP failure returns `{:error, reason}`.
- API key is loaded from env; not present in source.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Call `get_quote("AAPL")` with mocked 200 response | `{:ok, %{price: _, change: _, ...}}` |
| 2 | Call `get_quote("INVALIDXYZ")` with mocked 200 but empty/error body | `{:error, :not_found}` or equivalent |
| 3 | Call `get_technical_indicator("AAPL", :rsi, %{period: 14})` with mock | `{:ok, [%{date: _, value: _}, ...]}` |
| 4 | Simulate HTTP 500 | `{:error, :server_error}` |
| 5 | Verify API key is read from config, not hardcoded | Confirmed via grep or config inspection |

---

## M2-003: Stocks context (search and overview)

### Ticket
**ID**: M2-003  
**Title**: Stocks context — search and overview

### Description (why this ticket is needed)
Users need to find stocks by ticker or name (autocomplete) and view an overview (price, change, key metrics). The Stocks context orchestrates cache checks and external API calls, and will later coordinate Analysis, Sentiment, and Institutional data into the overall recommendation. For M2 the overview is partial (technical only), but the endpoint contract is established.

### Required tasks
- [x] Create `StockAnalysis.Stocks` context module.
- [x] Implement `search(query)`: call Alpha Vantage symbol search (or a static list for MVP); return list of `%{ticker, name, type, region}`.
- [x] Implement `get_overview(ticker)`: fetch current quote (price, change, market cap, 52-week range) via cache → Alpha Vantage. Return a struct/map matching the `@repo/types` Stock type.
- [x] Expose API endpoints: `GET /api/stocks/search?q=` (auth required); `GET /api/stocks/:ticker` (auth required).
- [x] Controllers: parse params, call context, return JSON; 404 if ticker not found.
- [x] Add search and overview types to `packages/types` (e.g. `SearchResult`, `StockOverview`).
- [x] Update `packages/api-client` with `searchStocks(q)` and `getStock(ticker)`.

### Acceptance criteria
- `GET /api/stocks/search?q=AA` returns JSON array of matching tickers.
- `GET /api/stocks/AAPL` returns JSON with price, change, and key metrics.
- Invalid ticker returns 404.
- Data is cached per TTL; second request within TTL does not call external API.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | GET /api/stocks/search?q=AAPL (with valid JWT) | 200, JSON array containing AAPL |
| 2 | GET /api/stocks/AAPL | 200, JSON with price, change, volume, etc. |
| 3 | GET /api/stocks/AAPL again within 15s | Same data; no new Alpha Vantage call (verify via logs or mock) |
| 4 | GET /api/stocks/INVALIDXYZ | 404 |
| 5 | From web or mobile app, call `api.searchStocks("AAPL")` | Returns typed array |

---

## M2-004: Analysis context — technical indicators and score

### Ticket
**ID**: M2-004  
**Title**: Analysis context — technical indicators and score

### Description (why this ticket is needed)
The Technical Analysis tab requires computed indicator values (RSI, MACD, SMA, Bollinger Bands, ATR, ADX) and an aggregated technical score (0–100). The Analysis context wraps Alpha Vantage indicator calls, caches results (1h TTL), and runs a scoring algorithm that maps indicator signals to an overall score.

### Required tasks
- [x] Create `StockAnalysis.Analysis` context module.
- [x] Implement `get_technical(ticker)`: for each indicator (RSI-14, MACD, SMA-20/50/200, Bollinger, ATR, ADX, Stochastic), fetch via cache → AlphaVantage integration; return combined map.
- [x] Implement `compute_technical_score(indicators)`: apply rules (e.g. RSI < 30 bullish, > 70 bearish; price above SMA-200 bullish; MACD crossover) and return score 0–100 with buy/sell signal strength.
- [x] Include support/resistance estimate and trend direction (bullish/bearish arrows) in the response.
- [x] Cache the full technical result per ticker with 1h TTL.
- [x] Expose endpoint: `GET /api/stocks/:ticker/technical` → JSON with indicators, score, signal.
- [x] Add `TechnicalAnalysis` type to `packages/types`; update `packages/api-client` with `getStockTechnical(ticker)`.

### Acceptance criteria
- Endpoint returns all indicators with recent values and an aggregated score 0–100.
- Score changes based on indicator values (not a constant).
- Cached for 1h; second call within TTL returns cached data.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | GET /api/stocks/AAPL/technical | 200, JSON with RSI, MACD, SMAs, score, signal |
| 2 | Verify score is between 0 and 100 | Value in range |
| 3 | Call again within 1h | Same response; no external API call |
| 4 | With mocked extreme RSI (e.g. 20), verify score reflects bullish signal | Score higher than neutral baseline |
| 5 | Run `mix test` for Analysis context | All tests pass |

---

## M2-005: Unusual Whales integration — options flow and dark pool

### Ticket
**ID**: M2-005  
**Title**: Unusual Whales integration — basic options flow and dark pool

### Description (why this ticket is needed)
The institutional data (options flow and dark pool) is a key differentiator per the PRD. Even in M2 a basic version surfaces "smart money" signals alongside the technical tab. The integration module handles Unusual Whales API auth, HTTP, rate-limit awareness, and caching (1h TTL) with "as of" timestamps for transparency.

### Required tasks
- [x] Create module `StockAnalysis.Integrations.UnusualWhales`.
- [x] Configure API key via env `UNUSUAL_WHALES_API_KEY`.
- [x] Implement `get_options_flow(ticker)`: fetch recent unusual options activity; normalize into list of trades (type, strike, expiry, premium, quantity, sentiment).
- [x] Implement `get_dark_pool(ticker)`: fetch dark pool volume, net buy/sell, block trades; normalize.
- [x] Cache both with 1h TTL; include `fetched_at` timestamp in cached payload.
- [x] Rate-limit awareness: track calls; if approaching limit, skip fetch and return cached + `stale: true`.
- [x] Create `StockAnalysis.InstitutionalActivity` context with `get_basic(ticker)` that returns options flow + dark pool (delegates to integration + cache).
- [x] Expose endpoint: `GET /api/stocks/:ticker/institutional` → JSON with options flow summary and dark pool summary; include `data_as_of` timestamp.
- [x] Add types and api-client method for institutional basic data.

### Acceptance criteria
- Endpoint returns options flow trades and dark pool data for a valid ticker.
- Response includes `data_as_of` ISO timestamp.
- Data cached for 1h; repeat calls within TTL return cache.
- When rate limit is near, returns stale cache with `stale: true` flag instead of failing.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | GET /api/stocks/AAPL/institutional | 200, JSON with options flow array and dark pool object |
| 2 | Verify `data_as_of` is recent ISO timestamp | Timestamp within last hour |
| 3 | Call again within 1h | Same data, no external call |
| 4 | Mock rate limit exceeded; call endpoint | Returns cached data with `stale: true` |
| 5 | Invalid ticker | 404 or empty data with appropriate message |

---

## M2-006: Stock search UI (web)

### Ticket
**ID**: M2-006  
**Title**: Stock search UI — web (Next.js)

### Description (why this ticket is needed)
Users need to find stocks quickly. An autocomplete search bar in the navbar (or dedicated search page) provides fast feedback as the user types, calls the API search endpoint, and navigates to the stock detail page on selection. This is the primary entry point into the analysis experience on web.

### Required tasks
- [x] Add search bar component to the top navbar (or a global search page); use a debounced input (e.g. 300ms).
- [x] On input change, call `api.searchStocks(query)` from `@repo/api-client`; display results in a dropdown with ticker and company name.
- [x] On result selection, navigate to `/stocks/[ticker]`.
- [x] Handle loading state (spinner or skeleton in dropdown), empty results ("No results"), and errors.
- [x] Persist recent searches locally (e.g. localStorage, last 5).
- [x] Style with Tailwind / Shadcn — clean, responsive.

### Acceptance criteria
- Typing "AA" shows matching tickers within ~500ms of debounce.
- Clicking a result navigates to `/stocks/AAPL` (or selected ticker).
- Empty query or no results shows appropriate message.
- Recent searches appear before typing (optional).

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Type "AAPL" in search bar | Dropdown with AAPL and related results |
| 2 | Click AAPL result | Navigate to /stocks/AAPL |
| 3 | Type "XYZNOTREAL" | "No results" message |
| 4 | Clear input | Dropdown closes (or shows recent) |
| 5 | Resize browser to mobile width | Search bar still usable (responsive) |

---

## M2-007: Stock overview and Technical tab (web)

### Ticket
**ID**: M2-007  
**Title**: Stock overview and Technical Analysis tab — web (Next.js)

### Description (why this ticket is needed)
The stock detail page is the main product experience. The overview section shows price, change, and key metrics; the Technical tab shows an interactive chart and indicators. This ticket wires the web UI to the API endpoints built in M2-003 and M2-004, and lays out the tab structure that will be extended in M3.

### Required tasks
- [x] Create `/stocks/[ticker]/page.tsx` (App Router dynamic route).
- [x] Fetch stock overview from `api.getStock(ticker)` (server component or React Query); display price, 24h change (colored), market cap, P/E placeholder, 52-week range.
- [x] Add tab navigation UI: "Technical | Fundamental | Emotional | Institutional" — only Technical is active for M2; others show "Coming soon" or skeleton.
- [x] Tab state in URL: `?tab=technical` (default), update on click; use `useSearchParams`.
- [x] **Technical tab**: Fetch `api.getStockTechnical(ticker)` with React Query.
  - [x] Interactive price chart: integrate Lightweight Charts (TradingView) or Recharts; show candlestick + volume; timeframe toggles (1D, 1M, 6M, 1Y).
  - [x] Indicators section: display RSI, MACD, SMA (20/50/200), Bollinger, ATR, ADX with values and interpretation (bullish/bearish label).
  - [x] Technical score display: 0–100 gauge or badge with signal (e.g. "Bullish").
- [x] Loading skeletons for overview and chart; error boundary for failed fetches.
- [ ] Optional: show basic institutional data (options flow summary, dark pool summary from M2-005) below technical or in Institutional tab placeholder.

### Acceptance criteria
- Navigating to `/stocks/AAPL` shows overview (price, change, metrics) and Technical tab.
- Chart renders with price data and volume; timeframe toggle changes chart range.
- Indicators display current values with interpretation labels.
- Technical score visible as a number 0–100 with signal.
- Tab URL updates; refreshing page restores correct tab.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Navigate to /stocks/AAPL | Overview section with price and metrics; Technical tab active |
| 2 | Click 1M, 6M timeframe toggles on chart | Chart updates to matching range |
| 3 | Scroll to indicators section | RSI, MACD, SMAs visible with values |
| 4 | Click "Fundamental" tab | "Coming soon" or placeholder |
| 5 | Refresh page with ?tab=technical in URL | Technical tab still active |
| 6 | Navigate to invalid ticker /stocks/XYZNOTREAL | 404 or error state |

---

## M2-008: Stock search and Technical tab (mobile)

### Ticket
**ID**: M2-008  
**Title**: Stock search and Technical Analysis tab — mobile (Expo)

### Description (why this ticket is needed)
Mobile users need the same search and analysis as web, adapted for native screens. This ticket adds a stock search screen, a stock detail screen with overview and Technical tab, and tab layout placeholders (Portfolio, Watchlist) using the shared api-client and types.

### Required tasks
- [x] Set up tab navigation layout in Expo Router: Home (search/trending), Portfolio (placeholder), Watchlist (placeholder), Profile (placeholder).
- [x] **Home tab / Search**: Search input with debounce; call `api.searchStocks(query)`; display results in a FlatList with ticker and name; navigate to stock detail on press.
- [x] **Stock detail screen** (`stocks/[ticker].tsx`): fetch overview from `api.getStock(ticker)`; display price, change, key metrics.
- [x] Add tab/segmented control for analysis tabs (Technical active; others placeholder).
- [x] **Technical tab**: Fetch `api.getStockTechnical(ticker)`.
  - [x] Price chart: integrate Victory Native or react-native-chart-kit; candlestick or line chart with timeframe toggle.
  - [x] Indicators list: RSI, MACD, SMAs, score — native list with labels and values.
  - [x] Technical score badge.
- [x] Loading and error states (ActivityIndicator, error card with retry).
- [x] Pull-to-refresh on stock detail to re-fetch.

### Acceptance criteria
- Search bar on home tab returns matching tickers; tapping navigates to stock detail.
- Stock detail shows overview and Technical tab with chart and indicators.
- Chart renders and timeframe toggle works.
- Pull-to-refresh re-fetches data.
- Uses same api-client and types as web.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Open app; type "AAPL" in search | Results list with AAPL |
| 2 | Tap AAPL | Stock detail screen with price and chart |
| 3 | Toggle chart timeframe (e.g. 1M → 1Y) | Chart updates |
| 4 | Scroll to indicators | RSI, MACD, score visible |
| 5 | Pull down to refresh | Data re-fetches (loading indicator briefly) |
| 6 | Search for invalid ticker | No results message |

---

## M2-009: Trending stocks endpoint and UI

### Ticket
**ID**: M2-009  
**Title**: Trending stocks endpoint and UI

### Description (why this ticket is needed)
Before users search, they need a starting point. A trending/popular stocks section on the home screen (web and mobile) gives users immediate tickers to explore and increases engagement from the first visit.

### Required tasks
- [x] **API**: Implement `GET /api/stocks/trending` in Stocks context — return a curated or computed list of popular tickers (e.g. top 10 by volume, or a static seed list for MVP). Cache for 1h.
- [x] Add type `TrendingStock` and api-client method `getTrending()`.
- [x] **Web**: Add a "Trending" or "Popular Stocks" section on the home/dashboard page; display ticker cards with name, price, change (colored); link each to `/stocks/[ticker]`.
- [x] **Mobile**: Add a trending section on the Home tab (below or in place of search when query is empty); FlatList of cards; tap navigates to stock detail.

### Acceptance criteria
- `/api/stocks/trending` returns a list of tickers with price and change.
- Web home page shows trending cards; clicking navigates to stock detail.
- Mobile home tab shows trending stocks when search is empty.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | GET /api/stocks/trending | 200, JSON array of ticker objects |
| 2 | Open web home page (logged in) | Trending section visible with stock cards |
| 3 | Click a trending card | Navigate to /stocks/[ticker] |
| 4 | Open mobile app home tab | Trending stocks visible |
| 5 | Tap a trending stock on mobile | Navigate to stock detail |

---

## Milestone 2 completion checklist

- [x] M2-001: ETS cache layer
- [x] M2-002: Alpha Vantage integration module
- [x] M2-003: Stocks context (search and overview)
- [x] M2-004: Analysis context — technical indicators and score
- [x] M2-005: Unusual Whales integration — options flow and dark pool
- [x] M2-006: Stock search UI (web)
- [x] M2-007: Stock overview and Technical tab (web)
- [x] M2-008: Stock search and Technical tab (mobile)
- [x] M2-009: Trending stocks endpoint and UI

**Done when**: Users can search stocks, view overview and Technical Analysis tab with chart, indicators, and score on both web and mobile; basic institutional data (options flow, dark pool) is visible; all data is cached per TTL. (Deployment pipeline moved to M5-010.)

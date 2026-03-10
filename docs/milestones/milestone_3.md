# Milestone 3 — Full Analysis & Institutional: Tickets

**Goal**: All four analysis dimensions (Technical, Fundamental, Emotional, Institutional) and the combined recommendation algorithm; full Institutional tab.  
**Dependencies**: M2 (Stock Analysis Core).  
**HLD reference**: §12.3 Logical Milestones — Milestone 3.

---

## M3-001: Financial Modeling Prep integration module

### Ticket
**ID**: M3-001  
**Title**: Financial Modeling Prep (FMP) integration module

### Description (why this ticket is needed)
FMP provides financial statements, valuation ratios, profitability metrics, and company profiles needed for the Fundamental Analysis tab. A dedicated integration module encapsulates API auth, HTTP, error handling, and response normalization, keeping the Analysis context clean.

### Required tasks
- [x] Create module `StockAnalysis.Integrations.FMP`.
- [x] Configure API key via env `FMP_API_KEY`.
- [x] Implement functions: `get_profile(ticker)` (description, sector, industry, market cap, employees, HQ), `get_ratios(ticker)` (P/E, P/B, PEG, P/S, ROE, ROA, margins, current ratio, quick ratio, D/E, interest coverage), `get_income_statement(ticker, period)` (quarterly/annual, last 4q / 3y), `get_balance_sheet(ticker, period)`, `get_cash_flow(ticker, period)`.
- [x] Normalize responses into consistent structs/maps.
- [x] Handle errors: invalid ticker, HTTP failures, rate limit (250/day free).
- [x] Write tests with mocked HTTP responses.

### Acceptance criteria
- `FMP.get_profile("AAPL")` returns `{:ok, %{sector: _, industry: _, ...}}`.
- `FMP.get_ratios("AAPL")` returns normalized ratio map.
- Financial statements return lists of period entries.
- Invalid ticker or HTTP error returns `{:error, reason}`.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Call `get_profile("AAPL")` with mock | `{:ok, %{sector: "Technology", ...}}` |
| 2 | Call `get_ratios("AAPL")` with mock | `{:ok, %{pe_ratio: _, roe: _, ...}}` |
| 3 | Call `get_income_statement("AAPL", :quarterly)` with mock | `{:ok, [%{date: _, revenue: _, ...}, ...]}` |
| 4 | Call with invalid ticker | `{:error, :not_found}` |
| 5 | Simulate HTTP 500 | `{:error, :server_error}` |

---

## M3-002: Analysis context — fundamental metrics and score

### Ticket
**ID**: M3-002  
**Title**: Analysis context — fundamental metrics and score

### Description (why this ticket is needed)
The Fundamental Analysis tab needs aggregated metrics (valuation, profitability, financial health) and a fundamental score (0–100). The Analysis context calls FMP via cache, computes a score based on how metrics compare to industry norms or absolute thresholds, and returns a value assessment (undervalued/fairly valued/overvalued).

### Required tasks
- [x] Extend `StockAnalysis.Analysis` with `get_fundamental(ticker)`.
- [x] Fetch profile, ratios, and statements via cache (24h TTL) → FMP integration.
- [x] Implement `compute_fundamental_score(ratios, profile)`: scoring algorithm based on valuation (P/E vs industry), profitability (margins, ROE), and financial health (current ratio, D/E). Return score 0–100, value assessment label, growth rating, health rating.
- [x] Expose endpoint: `GET /api/stocks/:ticker/fundamental` → JSON with ratios, statements, profile, score, assessment.
- [x] Add `FundamentalAnalysis` type to `packages/types`; update api-client with `getStockFundamental(ticker)`.

### Acceptance criteria
- Endpoint returns valuation ratios, profitability metrics, health metrics, statements, score 0–100, and assessment label.
- Score varies based on metric values (not constant).
- Data cached 24h.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | GET /api/stocks/AAPL/fundamental | 200, JSON with ratios, score, assessment |
| 2 | Verify score is 0–100 and assessment is one of Undervalued/Fairly Valued/Overvalued | Values in expected set |
| 3 | Call again within 24h | Same data; no FMP call |
| 4 | GET /api/stocks/INVALIDXYZ/fundamental | 404 |

---

## M3-003: Reddit and news sentiment integration

### Ticket
**ID**: M3-003  
**Title**: Reddit and news sentiment integration

### Description (why this ticket is needed)
The Emotional Analysis tab surfaces social sentiment from Reddit (r/wallstreetbets, r/stocks, r/investing) and news headlines. Raw posts and articles need to be fetched, filtered by ticker, and passed through a sentiment engine. This ticket builds the data pipeline; M3-004 does the scoring.

### Required tasks
- [x] Create module `StockAnalysis.Integrations.Reddit`: fetch recent posts mentioning a ticker from target subreddits via Reddit HTTP API or PRAW-equivalent Elixir client. Return list of `%{title, body, score, num_comments, subreddit, created_utc, url}`.
- [x] Create module `StockAnalysis.Integrations.Finnhub` (news): `get_news(ticker)` → list of `%{headline, summary, source, datetime, url, sentiment_from_source}`.
- [x] Cache Reddit results per ticker, 30min TTL; cache news per ticker, 30min TTL.
- [x] Handle rate limits: Reddit 60/min, Finnhub 60/min.
- [x] Write tests with mocked responses for both.

### Acceptance criteria
- Reddit integration returns recent posts mentioning ticker from target subreddits.
- Finnhub integration returns recent news articles for ticker.
- Both cached at 30min; repeat calls within TTL use cache.
- Rate-limit-safe (log or back off).

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Call Reddit integration for "AAPL" (mocked) | List of posts with expected fields |
| 2 | Call Finnhub news for "AAPL" (mocked) | List of articles with headline, source, datetime |
| 3 | Call Reddit again within 30min | Returns cached; no HTTP call |
| 4 | Call with obscure ticker that has no posts | Empty list, no error |

---

## M3-004: Sentiment context and scoring engine

### Ticket
**ID**: M3-004  
**Title**: Sentiment context and scoring engine

### Description (why this ticket is needed)
Raw posts and articles need to be analyzed for sentiment polarity (bullish/bearish/neutral). The Sentiment context orchestrates fetching, analysis (via LLM or FinBERT/VADER), and aggregation into an overall sentiment score (-100 to +100, normalized to 0–100 for the recommendation). The result powers the Emotional Analysis tab and feeds into the recommendation algorithm.

### Required tasks
- [x] Create `StockAnalysis.Sentiment` context module.
- [x] Implement sentiment engine: call OpenAI/Claude (e.g. GPT-4o-mini or Claude Haiku) or local model (FinBERT/VADER) to classify text as bullish/bearish/neutral with confidence.
- [x] Implement `get_sentiment(ticker)`:
  1. Fetch Reddit posts and news articles (from integrations / cache).
  2. Run each through sentiment engine; cache individual results if desired.
  3. Aggregate: weighted average of post/article sentiments (weight by engagement for Reddit).
  4. Compute overall sentiment score (-100 to +100), trend (7d, 30d), mention count.
- [x] Return structured payload: overall score, trend, mention count, top posts with sentiment labels, news with sentiment.
- [x] Cache aggregated sentiment per ticker, 30min TTL.
- [x] Expose endpoint: `GET /api/stocks/:ticker/sentiment` → JSON.
- [x] Add `SentimentAnalysis` type to `packages/types`; update api-client with `getStockSentiment(ticker)`.

### Acceptance criteria
- Endpoint returns sentiment score, trend, mention count, top posts with labels, news with labels.
- Score varies by ticker and input data.
- Cached 30min.
- Graceful degradation: if LLM call fails, fall back to keyword-based or return partial data.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | GET /api/stocks/AAPL/sentiment | 200, JSON with score, trend, posts, news |
| 2 | Verify score is -100 to +100 | In range |
| 3 | Verify posts array has sentiment labels (Bullish/Bearish/Neutral) | Labels present |
| 4 | Call again within 30min | Cached response |
| 5 | Mock LLM failure; call endpoint | Returns partial data or fallback score |

---

## M3-005: Unusual Whales — full institutional data

### Ticket
**ID**: M3-005  
**Title**: Unusual Whales — congressional, insider, holdings, market tide, smart money score

### Description (why this ticket is needed)
M2 added basic options flow and dark pool. The full Institutional Activity tab (PRD §3.6) adds congressional trades, insider transactions, institutional holdings (13F), market tide, and a smart money score. These endpoints complete the institutional picture and feed the 20% weight in the recommendation.

### Required tasks
- [x] Extend `StockAnalysis.Integrations.UnusualWhales` with: `get_congressional(ticker)` (last 90d), `get_insider_trades(ticker)` (last 90d), `get_institutional_holdings(ticker)` (13F, top holders), `get_market_tide()` (overall market sentiment).
- [x] Normalize each response into typed structs.
- [x] Cache TTLs: congressional/insider 24h, holdings 7d, market tide 1h.
- [x] Extend `StockAnalysis.InstitutionalActivity` context: `get_full(ticker)` returns options flow + dark pool + congressional + insider + holdings + market tide.
- [x] Implement `compute_smart_money_score(options_flow, dark_pool, congressional, insider)`: aggregate institutional sentiment into 0–100 score.
- [x] Expose additional endpoints or extend existing:
  - `GET /api/institutional/:ticker/congressional`
  - `GET /api/institutional/:ticker/insider-trades`
  - `GET /api/institutional/:ticker/holdings`
  - `GET /api/institutional/market-tide`
  - `GET /api/institutional/:ticker/smart-money-score`
- [x] Add types and api-client methods for each.

### Acceptance criteria
- All institutional endpoints return data with correct cache TTLs and `data_as_of` timestamps.
- Smart money score is 0–100, computed from sub-signals.
- Rate limit handling: stale cache returned with `stale: true` when limit reached.
- Market tide returns market-wide sentiment (not per-ticker).

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | GET /api/institutional/AAPL/congressional | 200, JSON list of congressional trades |
| 2 | GET /api/institutional/AAPL/insider-trades | 200, JSON list of insider trades |
| 3 | GET /api/institutional/AAPL/holdings | 200, JSON list of top holders |
| 4 | GET /api/institutional/market-tide | 200, JSON with market sentiment score |
| 5 | GET /api/institutional/AAPL/smart-money-score | 200, score 0–100 |
| 6 | Repeat holdings within 7d | Cached; no API call |

---

## M3-006: Recommendation algorithm

### Ticket
**ID**: M3-006  
**Title**: Recommendation algorithm — weighted score and label

### Description (why this ticket is needed)
The stock overview shows an overall recommendation (Strong Buy / Buy / Hold / Sell / Strong Sell) with a confidence score. This is the product's core value proposition — combining four analysis dimensions into one actionable label. The algorithm must be transparent and tunable.

### Required tasks
- [x] Create module or function in Analysis context: `compute_recommendation(ticker)`.
  1. Get technical score (0–100) from Analysis.
  2. Get fundamental score (0–100) from Analysis.
  3. Get sentiment score (normalized to 0–100) from Sentiment.
  4. Get smart money score (0–100) from InstitutionalActivity.
  5. Weighted sum: `0.30*tech + 0.30*fund + 0.20*sentiment + 0.20*institutional`.
  6. Map to label: 0–20 Strong Sell, 20–40 Sell, 40–60 Hold, 60–80 Buy, 80–100 Strong Buy.
  7. Confidence: derived from sub-score agreement (e.g. low variance = high confidence).
- [x] Update `GET /api/stocks/:ticker` response to include `recommendation`, `recommendation_score`, and `confidence`.
- [x] Handle partial data: if a sub-score is unavailable, compute with available scores and note reduced confidence.
- [x] Add recommendation fields to `StockOverview` type in `packages/types`.

### Acceptance criteria
- Stock overview JSON includes recommendation label, score, and confidence.
- Recommendation changes based on underlying sub-scores.
- Partial data (e.g. sentiment unavailable) still produces a recommendation with lower confidence.
- Score bands map correctly to labels.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | GET /api/stocks/AAPL | Response includes `recommendation`, `recommendation_score`, `confidence` |
| 2 | Mock all sub-scores at 90 | Recommendation = "Strong Buy", score ~90 |
| 3 | Mock all sub-scores at 30 | Recommendation = "Sell", score ~30 |
| 4 | Mock sentiment unavailable; others at 70 | Recommendation computed; confidence < when all present |
| 5 | Run `mix test` for recommendation logic | All tests pass |

---

## M3-007: Fundamental Analysis tab (web)

### Ticket
**ID**: M3-007  
**Title**: Fundamental Analysis tab — web (Next.js)

### Description (why this ticket is needed)
Users need to view valuation ratios, profitability metrics, financial health indicators, financial statements, and company overview in a dedicated tab. This ticket builds the Fundamental tab UI and wires it to the API endpoint from M3-002.

### Required tasks
- [x] Activate the "Fundamental" tab on the stock detail page (remove "Coming soon").
- [x] Fetch `api.getStockFundamental(ticker)` via React Query when tab is active.
- [x] **Valuation section**: display P/E (with industry avg if available), P/B, PEG, P/S in cards or table.
- [x] **Profitability section**: gross margin, operating margin, net margin, ROE, ROA.
- [x] **Financial health section**: current ratio, quick ratio, D/E, interest coverage.
- [x] **Financial statements**: collapsible or tabbed sections for income statement, balance sheet, cash flow; quarterly and annual toggle.
- [x] **Company overview**: description, sector, industry, market cap, employees, HQ.
- [x] **Fundamental score**: display score 0–100 with assessment label (Undervalued / Fairly Valued / Overvalued).
- [x] Loading skeletons and error handling.

### Acceptance criteria
- Fundamental tab loads data and displays all sections.
- Score and assessment label visible.
- Financial statements show at least last 4 quarters.
- Tab URL `?tab=fundamental` works.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Navigate to /stocks/AAPL?tab=fundamental | Fundamental tab active with data |
| 2 | Verify P/E, P/B, margins, ratios visible | Values rendered |
| 3 | Toggle income statement quarterly/annual | Data updates |
| 4 | Check company overview section | Sector, description visible |
| 5 | Refresh page with ?tab=fundamental | Tab persists |

---

## M3-008: Emotional Analysis tab (web)

### Ticket
**ID**: M3-008  
**Title**: Emotional Analysis tab — web (Next.js)

### Description (why this ticket is needed)
The Emotional tab is a unique differentiator — showing Reddit sentiment, news sentiment, and a smart money subsection. Users see what the crowd and institutions "feel" about a stock. This tab displays the sentiment score, social posts with labels, news, and a summary of whale activity.

### Required tasks
- [x] Activate the "Emotional" tab on the stock detail page.
- [x] Fetch `api.getStockSentiment(ticker)` via React Query.
- [x] **Sentiment overview**: gauge or visual meter (Very Bearish → Very Bullish); score; 7d/30d trend; mention count.
- [x] **Reddit section**: top 3–5 posts with subreddit, title excerpt, upvotes, sentiment label (Bullish/Bearish/Neutral), timestamp.
- [x] **News section**: recent headlines with source, date, sentiment label.
- [x] **Smart money subsection**: brief options flow and dark pool summary (from institutional data or separate call); link to full Institutional tab.
- [x] Loading skeletons and error handling.

### Acceptance criteria
- Emotional tab loads and displays sentiment gauge, score, posts, news.
- Posts show sentiment labels.
- Smart money subsection shows brief whale summary.
- Tab URL `?tab=emotional` works.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Navigate to /stocks/AAPL?tab=emotional | Emotional tab active |
| 2 | Verify sentiment gauge and score visible | Score rendered (-100 to +100) |
| 3 | Check Reddit posts section | 3–5 posts with labels |
| 4 | Check news section | Headlines with sentiment |
| 5 | Click link to Institutional tab from smart money subsection | Navigates to Institutional tab |

---

## M3-009: Institutional Activity tab (web)

### Ticket
**ID**: M3-009  
**Title**: Full Institutional Activity tab — web (Next.js)

### Description (why this ticket is needed)
The Institutional tab showcases premium Unusual Whales data: options flow feed, dark pool, congressional trades, insider transactions, institutional holdings, and the smart money score. This is the most data-rich tab and a competitive differentiator.

### Required tasks
- [ ] Activate the "Institutional" tab on the stock detail page.
- [ ] Fetch institutional endpoints via React Query (or a single aggregate call).
- [ ] **Quick stats cards**: Smart Money Score, Institutional Flow (net call/put premium), Dark Pool indicator, Insider Sentiment.
- [ ] **Options flow feed**: table of recent unusual trades (date, type, strike, expiry, premium, sentiment); filter by calls/puts; highlight > $1M in gold.
- [ ] **Dark pool section**: volume summary, net buying/selling, block trades list, 30d chart.
- [ ] **Congressional section**: recent trades table (name, party, buy/sell, amount range, date); net sentiment.
- [ ] **Insider section**: recent trades table (name, title, type, shares, price, value, date); net sentiment and interpretation.
- [ ] **Holdings section**: top institutional holders table (name, shares, portfolio %, change, report date).
- [ ] **Disclaimers**: congressional STOCK Act disclaimer; general informational disclaimer.
- [ ] Loading skeletons; "as of" timestamps on each section.

### Acceptance criteria
- All sections render with data or "No data available" for tickers without activity.
- Smart money score visible as 0–100.
- Options flow filterable by calls/puts.
- Congressional disclaimer visible.
- `data_as_of` timestamps shown per section.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Navigate to /stocks/AAPL?tab=institutional | All sections rendered |
| 2 | Filter options flow to "Calls only" | Table updates to show only calls |
| 3 | Verify congressional disclaimer visible | Text present |
| 4 | Check "as of" timestamps | Each section shows recent timestamp |
| 5 | Navigate to a small-cap ticker with no institutional data | Sections show "No data" gracefully |

---

## M3-010: Recommendation badge on stock overview (web)

### Ticket
**ID**: M3-010  
**Title**: Recommendation badge and confidence on stock overview — web

### Description (why this ticket is needed)
The overall recommendation is the primary output of the platform. It must be prominently displayed on the stock overview section so users see the verdict immediately. This ticket adds the recommendation badge, score, and confidence to the existing overview layout built in M2.

### Required tasks
- [ ] Update stock overview component to read `recommendation`, `recommendation_score`, and `confidence` from the API response.
- [ ] Display a large badge with the label (Strong Buy / Buy / Hold / Sell / Strong Sell) color-coded (green → red).
- [ ] Display confidence as a percentage (e.g. "78% confidence").
- [ ] Show the four sub-scores in a small breakdown (e.g. mini bars or chips) so users see what drives the recommendation.

### Acceptance criteria
- Recommendation badge visible on every stock detail page.
- Badge color matches sentiment (green for buy, red for sell, neutral for hold).
- Confidence percentage displayed.
- Sub-score breakdown visible.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Navigate to /stocks/AAPL | Recommendation badge visible (e.g. "Buy") |
| 2 | Verify badge color is green-ish for Buy | Correct color |
| 3 | Verify confidence percentage shown | E.g. "72% confidence" |
| 4 | Verify sub-score breakdown | 4 scores visible (tech, fund, sentiment, institutional) |

---

## M3-011: All four analysis tabs (mobile)

### Ticket
**ID**: M3-011  
**Title**: All four analysis tabs and recommendation — mobile (Expo)

### Description (why this ticket is needed)
Mobile users need the same four tabs and recommendation as web. This ticket activates Fundamental, Emotional, and Institutional tabs on the mobile stock detail screen and adds the recommendation badge to the overview.

### Required tasks
- [ ] Activate all four tab segments on mobile stock detail screen.
- [ ] **Fundamental tab**: fetch and display ratios, statements (collapsible), company overview, score. Adapt layout for mobile (cards, scrollable lists).
- [ ] **Emotional tab**: sentiment gauge, top posts (FlatList), news headlines, smart money summary.
- [ ] **Institutional tab**: quick stats, options flow (scrollable table or list), dark pool, congressional, insider, holdings. Disclaimers. "as of" timestamps.
- [ ] **Recommendation badge**: display on stock overview section with label, color, confidence, sub-scores.
- [ ] Use same api-client methods and types as web.
- [ ] Loading and error states for each tab.

### Acceptance criteria
- All four tabs active and display data on mobile.
- Recommendation badge on overview with label and confidence.
- Layout is native-friendly (no horizontal scrolling for key data).
- All data comes from same API endpoints as web.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Open stock detail on mobile | Recommendation badge visible |
| 2 | Tap Fundamental tab | Ratios and score display |
| 3 | Tap Emotional tab | Sentiment gauge and posts display |
| 4 | Tap Institutional tab | Options flow, dark pool, congressional data visible |
| 5 | Rotate device (if supported) | Layout adapts gracefully |

---

## Milestone 3 completion checklist

- [x] M3-001: FMP integration module
- [x] M3-002: Fundamental metrics and score
- [x] M3-003: Reddit and news sentiment integration
- [x] M3-004: Sentiment context and scoring engine
- [x] M3-005: Unusual Whales — full institutional data
- [x] M3-006: Recommendation algorithm
- [x] M3-007: Fundamental Analysis tab (web)
- [x] M3-008: Emotional Analysis tab (web)
- [x] M3-009: Institutional Activity tab (web)
- [x] M3-010: Recommendation badge (web)
- [x] M3-011: All four tabs and recommendation (mobile)

**Done when**: All four analysis tabs display real data on web and mobile; recommendation badge shows weighted score, label, and confidence; institutional tab shows options flow, dark pool, congressional, insider, and holdings with correct cache and rate-limit behavior.

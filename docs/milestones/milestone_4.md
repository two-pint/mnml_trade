# Milestone 4 — Paper Trading: Tickets

**Goal**: End-to-end paper trading: create portfolio, execute market orders, view holdings and transaction history, basic performance.  
**Dependencies**: M2 (price source). Can parallelize with M3.  
**HLD reference**: §12.4 Logical Milestones — Milestone 4.

---

## M4-001: Paper trading database schemas and migrations

### Ticket
**ID**: M4-001  
**Title**: Paper trading database schemas and migrations

### Description (why this ticket is needed)
Paper trading requires three new database tables — portfolios, holdings, and transactions — with relationships to the existing User table. Getting the schemas and indexes right up front prevents data integrity issues and expensive migrations later. These tables back the entire paper trading feature.

### Required tasks
- [x] Create Ecto schema and migration for `paper_portfolios`: `user_id` (references users), `name` (string), `description` (text, nullable), `starting_balance` (decimal, default 100_000), `cash_balance` (decimal), `is_active` (boolean, default true), timestamps. Index on `user_id`.
- [x] Create Ecto schema and migration for `paper_holdings`: `portfolio_id` (references paper_portfolios, on_delete cascade), `ticker` (string), `quantity` (decimal), `average_cost` (decimal), `total_cost` (decimal), `last_updated` (utc_datetime), timestamps. Unique index on `(portfolio_id, ticker)`.
- [x] Create Ecto schema and migration for `paper_transactions`: `portfolio_id` (references paper_portfolios, on_delete cascade), `ticker` (string), `transaction_type` (string: "buy"/"sell"), `quantity` (decimal), `price_per_share` (decimal), `total_amount` (decimal), `recommendation_at_time` (string, nullable), `notes` (text, nullable), `executed_at` (utc_datetime), timestamps. Index on `(portfolio_id, executed_at DESC)`, index on `(portfolio_id, ticker)`.
- [x] Add associations in schemas: Portfolio `has_many` holdings and transactions; holdings and transactions `belongs_to` portfolio.
- [x] Run migrations and verify in dev and test.

### Acceptance criteria
- All three tables created with correct columns, types, and constraints.
- Foreign keys cascade on portfolio delete.
- Unique index on `(portfolio_id, ticker)` for holdings prevents duplicate ticker entries per portfolio.
- `mix ecto.migrate` succeeds; `mix ecto.rollback` succeeds.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Run `mix ecto.migrate` | Tables created |
| 2 | Insert a portfolio via Repo | Row created with correct defaults |
| 3 | Insert a holding for the portfolio | Row created; unique index enforced |
| 4 | Insert duplicate (portfolio_id, ticker) holding | Constraint error |
| 5 | Delete portfolio | Holdings and transactions cascade-deleted |
| 6 | Run `mix ecto.rollback` (3 steps) | Tables dropped cleanly |

---

## M4-002: PaperTrading context — portfolio CRUD

### Ticket
**ID**: M4-002  
**Title**: PaperTrading context — portfolio CRUD

### Description (why this ticket is needed)
Users need to create, view, update, and delete paper portfolios. The context layer encapsulates all business logic — validation, ownership checks, and default values — so controllers stay thin. Each user gets at least one portfolio; the default starting balance is $100,000.

### Required tasks
- [x] Create `StockAnalysis.PaperTrading` context module.
- [x] Implement `create_portfolio(user_id, attrs)`: validate name required; set `cash_balance = starting_balance`; default starting balance 100_000 if not provided. Return `{:ok, portfolio}` or `{:error, changeset}`.
- [x] Implement `list_portfolios(user_id)`: return all portfolios for user with preloaded holdings count.
- [x] Implement `get_portfolio(user_id, portfolio_id)`: return portfolio with preloaded holdings; return `{:error, :not_found}` if not found or not owned by user.
- [x] Implement `update_portfolio(user_id, portfolio_id, attrs)`: allow updating name and description only (not balances).
- [x] Implement `delete_portfolio(user_id, portfolio_id)`: soft-delete (set `is_active = false`) or hard-delete; verify ownership.
- [x] Expose endpoints:
  - `GET /api/paper-trading/portfolios` — list
  - `POST /api/paper-trading/portfolios` — create
  - `GET /api/paper-trading/portfolios/:id` — show
  - `PUT /api/paper-trading/portfolios/:id` — update
  - `DELETE /api/paper-trading/portfolios/:id` — delete
- [x] Add types (`PaperPortfolio`, `CreatePortfolioRequest`) to `packages/types`; add api-client methods.

### Acceptance criteria
- User can create a portfolio; `cash_balance` equals `starting_balance`.
- User can only see/edit/delete their own portfolios.
- List returns all active portfolios for the user.
- Update only changes name/description, not balances.
- Delete removes or deactivates the portfolio.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | POST /api/paper-trading/portfolios with `{name: "Test"}` | 201, portfolio JSON with cash_balance = 100000 |
| 2 | GET /api/paper-trading/portfolios | 200, array containing the new portfolio |
| 3 | GET /api/paper-trading/portfolios/:id | 200, portfolio detail |
| 4 | PUT with `{name: "Renamed"}` | 200, updated name |
| 5 | DELETE /api/paper-trading/portfolios/:id | 200 or 204 |
| 6 | GET deleted portfolio | 404 |
| 7 | Try to GET another user's portfolio | 404 or 403 |

---

## M4-003: PaperTrading context — trade execution

### Ticket
**ID**: M4-003  
**Title**: PaperTrading context — trade execution (buy and sell)

### Description (why this ticket is needed)
The core paper trading action: users buy or sell shares at the current cached price. The context must validate the trade (sufficient cash or shares, min/max size), execute it atomically (create transaction, update holding, update cash), and return the result. Correctness here is critical — an off-by-one in cash or quantity breaks user trust.

### Required tasks
- [x] Implement `execute_trade(user_id, portfolio_id, %{ticker, side, quantity})` in PaperTrading context.
  - Verify ownership.
  - Get current price from Stocks cache (same 15s cache used by the UI).
  - **Buy**: validate `quantity >= 1`, `quantity <= 10_000`, `total_amount <= cash_balance`; optionally warn if `total_amount > 0.20 * portfolio_value`.
  - **Sell**: validate `quantity >= 1`, `quantity <= current_holding_quantity`.
  - In a DB transaction:
    1. Insert `PaperTransaction` with ticker, side, quantity, price_per_share, total_amount, executed_at.
    2. Update or insert `PaperHolding`: on buy, increase quantity and recalculate average cost; on sell, decrease quantity (delete holding if quantity reaches 0).
    3. Update portfolio `cash_balance`: subtract on buy, add on sell.
  - Return `{:ok, %{transaction: tx, portfolio: updated_portfolio}}` or `{:error, reason}`.
- [x] Implement average cost calculation: `new_avg = (old_total_cost + new_total_cost) / (old_qty + new_qty)`.
- [ ] Optionally capture `recommendation_at_time` from current recommendation (if available).
- [x] Expose endpoint: `POST /api/paper-trading/portfolios/:id/trade` with body `{ticker, side, quantity}`.
- [x] Add `ExecuteTradeRequest` and `TradeResult` types to `packages/types`; update api-client.

### Acceptance criteria
- Buy deducts cash, creates/updates holding with correct average cost, and records transaction.
- Sell adds cash, reduces holding quantity (removes if 0), and records transaction.
- Buying with insufficient cash returns error (no partial fill).
- Selling more than owned returns error.
- All DB changes in a single transaction (rollback on any failure).
- Trade response includes executed price and timestamp.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Create portfolio (cash 100k); buy 10 AAPL at $175 | Cash = 98,250; holding: 10 shares, avg $175 |
| 2 | Buy 10 more AAPL at $180 | Cash = 96,450; holding: 20 shares, avg $177.50 |
| 3 | Sell 5 AAPL at $180 | Cash = 97,350; holding: 15 shares, avg $177.50 |
| 4 | Sell all remaining 15 AAPL | Cash updated; holding removed |
| 5 | Try to buy with insufficient cash | Error returned; no DB changes |
| 6 | Try to sell 100 when only 10 owned | Error returned |
| 7 | Try to buy 0 or -1 shares | Validation error |
| 8 | Try to buy 10,001 shares | Validation error (max size) |

---

## M4-004: Holdings and transaction history endpoints

### Ticket
**ID**: M4-004  
**Title**: Holdings and transaction history API endpoints

### Description (why this ticket is needed)
The portfolio dashboard needs a list of current holdings (with current prices for unrealized P&L) and a paginated transaction history. These are read-only endpoints that query existing data and enrich holdings with current market prices from the cache.

### Required tasks
- [x] Implement `list_holdings(user_id, portfolio_id)` in PaperTrading context: return holdings with current price (from Stocks cache), current value, and gain/loss ($ and %) per holding.
- [x] Implement `list_transactions(user_id, portfolio_id, opts)`: paginated (default 20/page), filterable by ticker, type (buy/sell), date range. Return total count for pagination.
- [x] Implement `get_transaction(user_id, portfolio_id, transaction_id)`: single transaction detail.
- [x] Expose endpoints:
  - `GET /api/paper-trading/portfolios/:id/holdings`
  - `GET /api/paper-trading/portfolios/:id/transactions?page=1&per_page=20&ticker=&type=&from=&to=`
  - `GET /api/paper-trading/portfolios/:id/transactions/:tx_id`
- [x] Add types and api-client methods for holdings list and transaction list/detail.

### Acceptance criteria
- Holdings endpoint returns each holding with current price, value, gain/loss.
- Transactions endpoint is paginated and filterable.
- Single transaction detail returns full trade info.
- All scoped by user ownership.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | After buying AAPL and MSFT, GET holdings | 200, array with 2 holdings, each with current price and gain/loss |
| 2 | GET transactions?page=1&per_page=2 | 200, 2 transactions, total count in response |
| 3 | GET transactions?ticker=AAPL | Only AAPL transactions |
| 4 | GET transactions?type=buy | Only buy transactions |
| 5 | GET transactions/:tx_id | Full detail for one transaction |
| 6 | GET holdings for another user's portfolio | 404 or 403 |

---

## M4-005: Performance metrics endpoint

### Ticket
**ID**: M4-005  
**Title**: Performance metrics endpoint

### Description (why this ticket is needed)
Users want to know how their portfolio is doing: total return, best/worst trade, win rate. The performance endpoint computes these metrics from holdings and transactions and returns them in a format ready for the dashboard cards and charts.

### Required tasks
- [x] Implement `get_performance(user_id, portfolio_id)` in PaperTrading context:
  - Total portfolio value: `cash_balance + sum(holding_quantity * current_price)`.
  - Total return: `(current_value - starting_balance) / starting_balance * 100`.
  - Realized gains: sum of `(sell_price - avg_cost) * quantity` for sell transactions.
  - Unrealized gains: sum of `(current_price - avg_cost) * quantity` for current holdings.
  - Best trade: sell transaction with highest % gain.
  - Worst trade: sell transaction with highest % loss.
  - Win rate: `profitable_sells / total_sells * 100`.
  - Total trades count.
  - Most traded ticker.
- [x] Expose endpoint: `GET /api/paper-trading/portfolios/:id/performance`.
- [x] Add `PortfolioPerformance` type; update api-client.

### Acceptance criteria
- Performance endpoint returns all metrics.
- Total value matches cash + holdings at current prices.
- Win rate is accurate against sell transactions.
- Empty portfolio (no trades) returns zero/neutral metrics without errors.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Create portfolio, no trades; GET performance | Total value = starting balance, return = 0%, win rate = 0% |
| 2 | Buy 10 AAPL at $170; price rises to $180; GET performance | Unrealized gain = $100; total return positive |
| 3 | Sell 5 AAPL at $180 (profit); sell 5 at $165 (loss); GET performance | Realized gains computed; win rate = 50%; best and worst trade identified |
| 4 | Verify total value = cash + holdings value | Matches |

---

## M4-006: Portfolio dashboard (web)

### Ticket
**ID**: M4-006  
**Title**: Portfolio dashboard — web (Next.js)

### Description (why this ticket is needed)
The portfolio page is where users track their paper trading activity. It shows the portfolio value, cash, quick stats, a holdings table, and a performance chart. This is the web implementation using data from the API endpoints built in M4-002 through M4-005.

### Required tasks
- [x] Create `/portfolio/page.tsx` (or `/portfolio/[id]/page.tsx` if multiple portfolios).
- [x] Fetch portfolio, holdings, and performance via React Query.
- [x] **Header**: portfolio name, total value, total return ($ and %, colored).
- [x] **Quick stats cards**: Total Return, Best Performer, Worst Performer, Total Trades, Win Rate.
- [x] **Holdings table**: ticker, name, quantity, avg cost, current price, value, gain/loss ($ and %), % of portfolio. Click row to navigate to stock analysis.
- [x] **Performance chart**: portfolio value over time (1W, 1M, 3M, 1Y timeframe toggles). Use Recharts or Lightweight Charts.
- [x] **Cash available**: displayed prominently.
- [x] Add "Portfolio" link to top navbar.
- [x] Loading skeletons and empty state ("No holdings yet — start by analyzing a stock").

### Acceptance criteria
- Portfolio page shows all sections with live data.
- Holdings table rows link to stock analysis page.
- Performance chart renders with timeframe toggles.
- Empty portfolio shows helpful empty state.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Navigate to /portfolio | Portfolio dashboard with value, cash, stats |
| 2 | Verify holdings table shows current holdings | Correct tickers, quantities, gain/loss |
| 3 | Click a holding row | Navigate to /stocks/[ticker] |
| 4 | Toggle performance chart timeframe | Chart updates |
| 5 | With no holdings, view page | Empty state message displayed |

---

## M4-007: Trade modal (web)

### Ticket
**ID**: M4-007  
**Title**: Trade modal — web (Next.js)

### Description (why this ticket is needed)
Users must be able to buy or sell directly from a stock analysis page. A trade modal overlays the current page with buy/sell tabs, quantity input, price display, cost preview, and confirmation. This is the main action flow connecting analysis to paper trading.

### Required tasks
- [x] Create a trade modal/drawer component (e.g. Shadcn Dialog or custom).
- [x] Add "Trade" button on every stock detail page; clicking opens the modal with the ticker pre-filled.
- [x] **Modal contents**: Buy/Sell tab toggle; ticker (read-only, pre-filled); current price (from stock data, auto-refreshes or shows cached); quantity input (number, min 1); total cost preview (`quantity * price`); available cash (buy) or shares owned (sell); portfolio selector (if multiple portfolios — Phase 2, for now default portfolio).
- [x] **Validation**: insufficient cash (buy), insufficient shares (sell), min/max quantity. Show inline errors.
- [x] **Preview and confirm**: show summary before executing; "Execute Trade" button; loading state on submit.
- [x] On success: show confirmation message (ticker, side, quantity, price, total); option to "View Portfolio" or "Continue Analyzing".
- [x] Call `api.executeTrade(portfolioId, {ticker, side, quantity})` from api-client.
- [x] Invalidate React Query cache for portfolio/holdings/performance on success.

### Acceptance criteria
- Trade modal opens from stock page with ticker pre-filled.
- Buy and sell work; success shows confirmation.
- Validation prevents invalid trades with clear error messages.
- Portfolio data refreshes after trade.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | On /stocks/AAPL, click "Trade" | Modal opens with AAPL pre-filled |
| 2 | Select Buy, enter 10 shares | Preview shows total cost |
| 3 | Click "Execute Trade" | Success message with trade details |
| 4 | Navigate to portfolio | Holdings updated with AAPL |
| 5 | Go back to AAPL, open trade, select Sell, enter more shares than owned | Error: insufficient shares |
| 6 | Try to buy with $0 cash | Error: insufficient cash |

---

## M4-008: Transaction history page (web)

### Ticket
**ID**: M4-008  
**Title**: Transaction history page — web (Next.js)

### Description (why this ticket is needed)
Users need a full view of past trades to understand their trading patterns and review decisions. A paginated, filterable transaction history table provides this. It also serves as an audit log for the paper portfolio.

### Required tasks
- [ ] Create transaction history section on the portfolio page (or separate `/portfolio/transactions` page).
- [ ] Fetch transactions with pagination via React Query.
- [ ] **Table columns**: date/time, ticker, type (Buy/Sell, color-coded), quantity, price per share, total amount.
- [ ] **Filters**: by ticker (text input), by type (buy/sell dropdown), by date range (date pickers).
- [ ] **Pagination**: page numbers or infinite scroll; 20 per page.
- [ ] Click a transaction row for detail view (optional modal or inline expand) showing full info and optional notes.
- [ ] Empty state if no transactions.

### Acceptance criteria
- Transaction history displays all trades, paginated.
- Filters work: selecting "buy" shows only buys; entering ticker filters by ticker.
- Clicking a row shows detail.
- Pagination controls work.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Execute several trades; navigate to transaction history | All trades listed |
| 2 | Filter by ticker "AAPL" | Only AAPL trades shown |
| 3 | Filter by type "sell" | Only sell trades shown |
| 4 | Navigate to page 2 (if >20 trades) | Next page loads |
| 5 | Click a transaction | Detail view or expansion shows full info |

---

## M4-009: Paper trading — mobile (Expo)

### Ticket
**ID**: M4-009  
**Title**: Paper trading UI — mobile (Expo)

### Description (why this ticket is needed)
Mobile users need the same paper trading capabilities as web: portfolio dashboard, trade execution, holdings, transaction history, and performance. The mobile implementation uses native components (bottom sheets, FlatLists, native charts) for a smooth experience.

### Required tasks
- [ ] **Portfolio tab**: activate in tab navigator. Show portfolio value, cash, quick stats cards, holdings FlatList (ticker, quantity, gain/loss, current price). Tap holding → navigate to stock detail.
- [ ] **Trade flow**: "Trade" button on stock detail screen opens a bottom sheet (or new screen). Buy/Sell toggle, quantity input, price, total preview, validation, confirm button. On success, show confirmation and option to view portfolio.
- [ ] **Transaction history**: scrollable list on portfolio tab (or sub-screen). Pull-to-refresh. Tap for detail.
- [ ] **Performance**: total return, win rate, best/worst trade cards above holdings list. Optional chart (Victory Native).
- [ ] Use same api-client methods and types as web.
- [ ] Loading and error states; haptic feedback on trade confirm (optional).

### Acceptance criteria
- Portfolio tab shows value, holdings, stats.
- Trade flow works from stock detail with validation.
- Transaction list is scrollable and refreshable.
- All data from same API as web.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Open Portfolio tab | Value, cash, holdings visible |
| 2 | Tap "Trade" on stock detail; buy 5 AAPL | Confirmation shown; portfolio updates |
| 3 | Tap a holding in portfolio | Navigate to stock detail |
| 4 | View transaction history | Recent trades listed |
| 5 | Pull-to-refresh on portfolio | Data reloads |

---

## Milestone 4 completion checklist

- [x] M4-001: Database schemas and migrations
- [x] M4-002: Portfolio CRUD
- [x] M4-003: Trade execution
- [x] M4-004: Holdings and transaction history endpoints
- [x] M4-005: Performance metrics endpoint
- [x] M4-006: Portfolio dashboard (web)
- [x] M4-007: Trade modal (web)
- [ ] M4-008: Transaction history page (web)
- [ ] M4-009: Paper trading (mobile)

**Done when**: Users can create a portfolio, buy/sell stocks at current price, view holdings with unrealized P&L, browse transaction history, and see performance metrics — on both web and mobile.

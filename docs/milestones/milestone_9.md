# Milestone 9 — Options Analysis Tools: Tickets

**Goal**: Options chain data, Greeks/IV calculation, break-even pricing, P&L payoff curves, unusual activity flow, and options paper trading.  
**Dependencies**: M2 (Finnhub integration, price source), M4 (paper trading schemas).  
**Data sources**: Finnhub `/stock/option-chain` for chain data; Unusual Whales `get_options_flow` for flow.

---

## M9-001: Finnhub options chain integration

### Ticket
**ID**: M9-001  
**Title**: Finnhub options chain integration

### Description (why this ticket is needed)
Options analysis requires real-time chain data — strikes, bids, asks, volumes, open interest, and implied volatility for every listed contract. Finnhub's `/stock/option-chain` endpoint provides this in a single call per ticker. Adding this to the existing Finnhub module keeps all Finnhub integration logic in one place, and caching the result in ETS (60s TTL) avoids hammering the free-tier rate limit (60 req/min).

### Required tasks
- [ ] Add `get_option_chain/1` to `StockAnalysis.Integrations.Finnhub`: call `GET /stock/option-chain?symbol=TICKER`, normalize response into `{:ok, %{ticker, expirations: [%{expiration_date, calls: [...], puts: [...]}]}}`.
- [ ] Normalize each contract into: `%{contract_name, strike, last_price, bid, ask, change, percent_change, volume, open_interest, implied_volatility, in_the_money}`.
- [ ] Cache results in `StockAnalysis.Cache` under key `"options:TICKER:chain"` with 60s TTL.
- [ ] Handle error cases: missing API key, rate limit (429), not found, server errors.
- [ ] Add unit tests with mocked HTTP responses.

### Acceptance criteria
- `get_option_chain("AAPL")` returns structured chain data grouped by expiration.
- Cached results are served for 60s without re-fetching.
- Error atoms match existing Finnhub patterns (`:api_key_missing`, `:rate_limit`, `:not_found`, `:server_error`).

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Call `get_option_chain("AAPL")` with mocked 200 response | Normalized chain with calls and puts per expiration |
| 2 | Call again within 60s | Cached result returned |
| 3 | Mock 429 response | `{:error, :rate_limit}` |
| 4 | Mock missing API key | `{:error, :api_key_missing}` |
| 5 | Mock 404 | `{:error, :not_found}` |

---

## M9-002: Options chain API endpoint

### Ticket
**ID**: M9-002  
**Title**: Options chain API endpoint

### Description (why this ticket is needed)
The frontend needs a REST endpoint to display the options chain table for a ticker. This ticket creates the Options context module (which wraps the Finnhub integration and adds an optional expiration filter), the controller, JSON view, route, and frontend types/api-client method.

### Required tasks
- [ ] Create `StockAnalysis.Options` context module with `get_chain/2` — accepts ticker and optional `expiration` filter string; delegates to Finnhub integration (or cache); filters expirations if specified.
- [ ] Create `StockAnalysisWeb.OptionsController` with `chain/2` action.
- [ ] Create `StockAnalysisWeb.OptionsJSON` with `chain/1` render function.
- [ ] Add route: `GET /api/options/:ticker/chain` (authenticated).
- [ ] Add TypeScript types: `OptionContract`, `OptionExpiration`, `OptionChain` to `packages/types/src/options.ts`.
- [ ] Add `getOptionChain(ticker, expiration?)` to `packages/api-client/src/options.ts`.
- [ ] Export from both packages' `index.ts`.

### Acceptance criteria
- `GET /api/options/AAPL/chain` returns JSON with expirations array containing calls/puts.
- `GET /api/options/AAPL/chain?expiration=2026-04-17` returns only that expiration.
- 401 if unauthenticated.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | GET /api/options/AAPL/chain (authenticated) | 200, chain data grouped by expiration |
| 2 | GET /api/options/AAPL/chain?expiration=2026-04-17 | 200, single expiration only |
| 3 | GET /api/options/AAPL/chain (no token) | 401 |
| 4 | GET /api/options/INVALID/chain | Error response |

---

## M9-003: Greeks calculator (Black-Scholes)

### Ticket
**ID**: M9-003  
**Title**: Greeks calculator (Black-Scholes)

### Description (why this ticket is needed)
Traders use Greeks (Delta, Gamma, Theta, Vega, Rho) to understand option sensitivity to price, time, and volatility. The Finnhub chain provides implied volatility, so we can compute all Greeks via Black-Scholes without a separate provider. A pure-function module keeps the math testable and independent of I/O.

### Required tasks
- [ ] Create `StockAnalysis.Options.Greeks` module implementing Black-Scholes:
  - `calculate/1` accepting `%{spot, strike, time_to_expiry, risk_free_rate, iv, type}` and returning `%{delta, gamma, theta, vega, rho}`.
  - Use Erlang `:math` for exp/log/sqrt; floats are acceptable for Greeks (they're approximations).
  - Standard normal CDF/PDF helpers (`norm_cdf/1`, `norm_pdf/1`).
  - `d1` and `d2` intermediate calculations.
- [ ] Add `greeks/2` function to `StockAnalysis.Options` context: given ticker + `%{strike, expiration, type}`, fetch chain, look up the contract's IV, compute Greeks.
- [ ] Add `greeks/2` action to `OptionsController`.
- [ ] Add route: `GET /api/options/:ticker/greeks?strike=X&expiration=Y&type=call`.
- [ ] Add `OptionsGreeks` TypeScript type and `getGreeks(ticker, params)` api-client method.

### Acceptance criteria
- Black-Scholes Greeks match known reference values (e.g. ATM call with 30d, 25% IV).
- API endpoint returns computed Greeks for a specific contract.
- Edge cases handled: zero time to expiry, zero IV.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Call `Greeks.calculate` with known inputs | Delta/Gamma/Theta/Vega/Rho match reference |
| 2 | ATM call, 30 days, 25% IV, spot=100, strike=100, r=0.05 | Delta ≈ 0.53, Gamma ≈ 0.055 |
| 3 | Deep ITM call | Delta ≈ 1.0 |
| 4 | Deep OTM put | Delta ≈ 0.0 |
| 5 | GET /api/options/AAPL/greeks?strike=175&expiration=2026-04-17&type=call | 200, Greeks JSON |
| 6 | Missing params | 422 error |

---

## M9-004: Break-even calculator

### Ticket
**ID**: M9-004  
**Title**: Break-even calculator

### Description (why this ticket is needed)
Before entering a trade, users need to know exactly what price the underlying must reach to break even. This varies by strategy — a simple long call breaks even at strike + premium, but multi-leg strategies (spreads, straddles, iron condors) have multiple break-even points. A dedicated calculator module handles all common strategies.

### Required tasks
- [ ] Create `StockAnalysis.Options.BreakEven` module with `calculate/1`:
  - Input: list of legs, each `%{strike, premium, type ("call"/"put"), side ("long"/"short"), quantity}`.
  - Single-leg: long call = strike + premium; long put = strike − premium; short call = strike + premium; short put = strike − premium.
  - Multi-leg: compute payoff at many price points, find zero-crossings for break-even prices.
  - Return `%{break_even_prices: [...], max_profit, max_loss}`.
- [ ] Add `breakeven/2` action to `OptionsController`.
- [ ] Add route: `POST /api/options/breakeven` (authenticated).
- [ ] Add `BreakEvenRequest`, `BreakEvenLeg`, `BreakEvenResult` TypeScript types and `calculateBreakEven(legs)` api-client method.

### Acceptance criteria
- Long call break-even is strike + premium.
- Vertical spread returns correct break-even and max profit/loss.
- Iron condor returns two break-even prices.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Long call: strike=100, premium=5 | Break-even = 105, max loss = −5, max profit = unlimited |
| 2 | Long put: strike=100, premium=3 | Break-even = 97, max loss = −3, max profit = 97 |
| 3 | Bull call spread: buy 100c@5, sell 110c@2 | Break-even = 103, max profit = 7, max loss = −3 |
| 4 | Iron condor: buy 90p@1, sell 95p@3, sell 105c@3, buy 110c@1 | Two break-even points, max profit = 4, max loss = −1 |
| 5 | POST /api/options/breakeven with legs | 200, result JSON |

---

## M9-005: P&L payoff calculator

### Ticket
**ID**: M9-005  
**Title**: P&L payoff calculator

### Description (why this ticket is needed)
A payoff diagram is the most intuitive way to visualize an options position's risk/reward profile across a range of underlying prices. The backend computes P&L at N price points spanning the range of strikes; the frontend renders the chart. Keeping the calculation server-side ensures consistency and lets the mobile app use the same data.

### Required tasks
- [ ] Create `StockAnalysis.Options.Payoff` module with `calculate/1`:
  - Input: list of legs `[%{strike, premium, type, side, quantity}]` and optional `%{min_price, max_price, steps}`.
  - Default range: min strike − 20% to max strike + 20%, 100 steps.
  - For each price point, compute net P&L across all legs.
  - Return `%{points: [%{price, pnl}], max_profit, max_loss}`.
- [ ] Add `payoff/2` action to `OptionsController`.
- [ ] Add route: `POST /api/options/payoff` (authenticated).
- [ ] Add `PayoffRequest`, `PayoffPoint`, `PayoffResult` TypeScript types and `calculatePayoff(legs)` api-client method.

### Acceptance criteria
- Single long call payoff matches expected hockey-stick shape.
- Spread payoff shows capped max profit and max loss.
- Response contains enough points (100) for smooth chart rendering.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Long call: strike=100, premium=5, quantity=1 | P&L = −5 at price<100, linear above 105 |
| 2 | Bull call spread | Capped payoff curve |
| 3 | Straddle | V-shaped payoff |
| 4 | POST /api/options/payoff | 200, array of {price, pnl} points |

---

## M9-006: Unusual options activity endpoint

### Ticket
**ID**: M9-006  
**Title**: Unusual options activity endpoint

### Description (why this ticket is needed)
Unusual Whales options flow data is currently bundled inside the institutional data response (`/api/stocks/:ticker/institutional`). A dedicated options flow endpoint allows the frontend to show a focused unusual activity feed with additional filtering (minimum premium, sentiment, option type) and computed enrichments (volume/OI ratio, premium notional).

### Required tasks
- [ ] Add `get_options_flow/2` to `StockAnalysis.Options` context: delegates to Unusual Whales integration; accepts filter opts `%{min_premium, sentiment, option_type}`.
- [ ] Enrich each flow trade with computed fields: `premium_notional` (premium × quantity × 100).
- [ ] Add `flow/2` action to `OptionsController`.
- [ ] Add route: `GET /api/options/:ticker/flow` (authenticated).
- [ ] Add `EnrichedOptionsFlow` TypeScript type (extends `OptionsFlowTrade` with `premium_notional`) and `getOptionsFlow(ticker, filters?)` api-client method.

### Acceptance criteria
- `GET /api/options/AAPL/flow` returns flow trades from Unusual Whales.
- `GET /api/options/AAPL/flow?min_premium=100000` filters by minimum premium.
- `GET /api/options/AAPL/flow?sentiment=bullish` filters by sentiment.
- Each trade includes computed `premium_notional`.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | GET /api/options/AAPL/flow | 200, list of flow trades |
| 2 | GET /api/options/AAPL/flow?min_premium=100000 | Only trades with premium >= 100000 |
| 3 | GET /api/options/AAPL/flow?sentiment=bullish | Only bullish trades |
| 4 | GET /api/options/AAPL/flow?option_type=call | Only call trades |
| 5 | Verify premium_notional computed correctly | premium × quantity × 100 |

---

## M9-007: Options paper trading

### Ticket
**ID**: M9-007  
**Title**: Options paper trading

### Description (why this ticket is needed)
Users who paper trade equities will want to paper trade options too. This requires new database tables (option holdings and option transactions) with additional fields beyond equities — strike, expiration, option type, premium per contract, and a Greeks snapshot at trade time. The context functions mirror the equity paper trading API but with options-specific validation.

### Required tasks
- [ ] Create migration for `paper_option_holdings`: `portfolio_id` (references paper_portfolios, on_delete cascade), `ticker` (string), `strike` (decimal), `expiration` (date), `option_type` (string: "call"/"put"), `side` (string: "long"/"short"), `quantity` (integer), `avg_premium` (decimal), `total_cost` (decimal), timestamps. Unique index on `(portfolio_id, ticker, strike, expiration, option_type, side)`.
- [ ] Create migration for `paper_option_transactions`: `portfolio_id` (references paper_portfolios, on_delete cascade), `ticker` (string), `strike` (decimal), `expiration` (date), `option_type` (string: "call"/"put"), `side` (string: "long"/"short"), `transaction_type` (string: "buy"/"sell"), `quantity` (integer), `premium_per_contract` (decimal), `total_amount` (decimal), `underlying_price_at_time` (decimal, nullable), `iv_at_time` (decimal, nullable), `delta_at_time` (decimal, nullable), `notes` (text, nullable), `executed_at` (utc_datetime), timestamps. Indexes on `(portfolio_id, executed_at DESC)` and `(portfolio_id, ticker)`.
- [ ] Create Ecto schemas: `StockAnalysis.PaperTrading.OptionHolding` and `StockAnalysis.PaperTrading.OptionTransaction`.
- [ ] Implement `execute_option_trade/4` in PaperTrading context:
  - Validate ownership, ticker, option type, side, quantity.
  - Fetch current option price from chain data (Finnhub).
  - Buy: deduct premium × quantity × 100 from cash; create/update option holding.
  - Sell: validate sufficient contracts; add proceeds to cash; reduce holding.
  - Record transaction with Greeks snapshot.
- [ ] Implement `list_option_holdings/3`, `list_option_transactions/3`, `get_option_performance/3`.
- [ ] Add controller actions, routes, and JSON views.
- [ ] Add TypeScript types and api-client methods.
- [ ] Run migrations; write context and controller tests.

### Acceptance criteria
- Users can buy and sell option contracts, deducting/adding premium × quantity × 100 from cash.
- Option holdings track strike, expiration, type, side, quantity, and average premium.
- Transactions record full trade details including Greeks snapshot.
- All operations scoped by user ownership.
- Expired options are handled gracefully.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Buy 5 AAPL 175c 2026-04-17 at $3.50 premium | Cash reduced by $1,750; option holding created |
| 2 | Buy 3 more of same contract at $4.00 | Holding updated: 8 contracts, avg premium recalculated |
| 3 | Sell 2 contracts at $5.00 | Cash increased by $1,000; holding: 6 contracts |
| 4 | Sell all remaining | Holding removed |
| 5 | Try to buy with insufficient cash | Error returned |
| 6 | Try to sell more contracts than owned | Error returned |
| 7 | GET option holdings | List with current prices and P&L |
| 8 | GET option transactions | Paginated history |

---

## M9-008: Web and mobile UI (placeholder)

### Ticket
**ID**: M9-008  
**Title**: Options analysis UI — web and mobile

### Description (why this ticket is needed)
The backend APIs from M9-001 through M9-007 need frontend surfaces. This placeholder ticket covers the web (Next.js) and mobile (Expo) UI components that will consume the options endpoints. Detailed sub-tickets will be created during implementation.

### Required tasks
- [ ] Options chain table component: calls on left, puts on right, grouped by expiration; highlight ITM contracts; show bid/ask/last/volume/OI/IV.
- [ ] Greeks display card: show computed Greeks for a selected contract.
- [ ] Break-even and P&L chart: interactive payoff diagram using the payoff endpoint data (Recharts/Victory).
- [ ] Options trade modal: select contract from chain, enter quantity, preview cost, execute trade.
- [ ] Unusual activity feed: filterable list of unusual options flow trades.
- [ ] Mobile equivalents using native components (bottom sheets, FlatLists).

### Acceptance criteria
- All options tools are accessible from the stock detail page.
- Chain table, Greeks card, payoff chart, trade modal, and flow feed render correctly.
- Mobile and web share the same API client and types.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Navigate to stock detail, open options tab | Chain table displayed |
| 2 | Select a contract | Greeks card populated |
| 3 | Build a strategy, view payoff chart | Chart renders with break-even lines |
| 4 | Execute an options paper trade | Confirmation shown; portfolio updated |
| 5 | View unusual activity | Flow trades listed with filters |

---

## M9-009: Deployment pipeline (Fly.io, Vercel, EAS)

### Ticket
**ID**: M9-009  
**Title**: Deployment pipeline (Fly.io, Vercel, EAS)

### Description (why this ticket is needed)
To validate the full stack and allow testing from real devices and shared URLs, the API and web app must deploy to production-like environments, and the mobile app must be buildable and testable via EAS. This ticket is placed at the end of Milestone 9 so that deployment includes all features (options, paper trading, push, Oban, etc.) and the complete set of API keys and config is documented in one place.

### API keys and secrets (Phoenix / Fly.io)

Set these as Fly secrets or in `fly.toml` env; never commit.

| Variable | Required | Purpose |
|----------|----------|---------|
| `DATABASE_URL` | Yes | Postgres connection URL (e.g. from `fly postgres attach`) |
| `SECRET_KEY_BASE` | Yes | Phoenix signing/encryption; generate with `mix phx.gen.secret` |
| `GUARDIAN_SECRET_KEY` | Yes | JWT signing; generate with `mix guardian.gen.secret` |
| `PHX_HOST` | Yes (prod) | Public hostname (e.g. `your-app.fly.dev`) |
| `CORS_ORIGINS` | Recommended | Comma-separated allowed origins (Vercel URL, preview URLs, Expo redirect URIs) |
| `ALPHA_VANTAGE_API_KEY` | No | Stock quotes, search, daily series (M2) |
| `UNUSUAL_WHALES_API_KEY` | No | Institutional/options flow (M2, M9) |
| `FMP_API_KEY` | No | Fundamentals (M3) |
| `FINNHUB_API_KEY` | No | Options chain (M9), sentiment |
| `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` | No | LLM for multi-agent analysis (M7) — add when M7 is implemented |
| `REDIS_URL` | No | Redis for caching/queues (M8) — add if M8 introduces Redis |
| `POOL_SIZE` | No | Ecto pool size (default 10) |
| `PORT` | No | Set by Fly; default 4000 |

### Required tasks
- [ ] **Phoenix on Fly.io**: Create Fly app (or use existing); attach or create Postgres. Set all required secrets and any optional API keys from the table above. Configure `mix release` and `fly deploy`; run migrations as part of deploy or via release command. Document deploy steps.
- [ ] **Next.js on Vercel**: Connect repo (or manual deploy); set build output to `apps/web` (or root with turbo filter). Set env: `NEXT_PUBLIC_API_URL` to Phoenix URL (e.g. `https://<app>.fly.dev`). Ensure CORS on Phoenix allows Vercel origin and preview URLs.
- [ ] **EAS for mobile**: Create EAS project; configure `app.json`/`eas.json` (e.g. development build profile). Set `EXPO_PUBLIC_API_URL` in EAS env or app config to production API URL for dev builds. If push notifications (M5) are used, ensure EAS project ID is set for Expo push. Document how to run `eas build --profile development` and install on device/simulator.
- [ ] Update API CORS config with production web URL and any Expo/redirect URIs if needed.
- [ ] Add a brief "Deployment" section to README or docs: how to deploy API, web, and how to build mobile for testing; include the API keys/secrets table or link to it.

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

## Milestone 9 completion checklist

- [ ] M9-001: Finnhub options chain integration
- [ ] M9-002: Options chain API endpoint
- [ ] M9-003: Greeks calculator (Black-Scholes)
- [ ] M9-004: Break-even calculator
- [ ] M9-005: P&L payoff calculator
- [ ] M9-006: Unusual options activity endpoint
- [ ] M9-007: Options paper trading
- [ ] M9-008: Web and mobile UI
- [ ] M9-009: Deployment pipeline (Fly.io, Vercel, EAS)

**Done when**: Users can view options chains, compute Greeks for any contract, calculate break-even prices and visualize P&L for multi-leg strategies, monitor unusual options activity, and paper trade options — on both web and mobile; and the full stack is deployable to Fly.io, Vercel, and EAS with all required and optional env documented.

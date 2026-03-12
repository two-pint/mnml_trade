# Milestone 6 — Historical Data & Background Sync: Tickets

**Goal**: Persist ticker metadata, daily price snapshots, and analysis score snapshots in Postgres so the app can show historical charts and trends without re-calling external APIs for every request. Background workers (Oban) keep the data fresh on a schedule.  
**Dependencies**: M2 (stocks/cache), M3 (analysis/scores), M5 (watchlist).  
**HLD reference**: §12.6 Logical Milestones — Milestone 6.

---

## M6-001: Add Oban dependency and configure

### Ticket
**ID**: M6-001  
**Title**: Add Oban dependency, configure queues, and add to supervision tree

### Description (why this ticket is needed)
Background jobs are needed to fetch and store price/score data on a schedule without blocking user requests. Oban is a robust, Postgres-backed job queue for Elixir that provides scheduling, retries, uniqueness constraints, and cron-like recurring jobs. Adding it now establishes the infrastructure that M6-005 workers will use.

### Required tasks
- [x] Add `oban` dependency to `mix.exs` (latest stable version). Oban is a Postgres-backed job processing library for Elixir — [docs](https://hexdocs.pm/oban).
- [x] Run `mix deps.get` to fetch the dependency.
- [x] Generate the Oban migrations: `mix ecto.gen.migration add_oban_jobs_table`, then call `Oban.Migration.up()` inside the migration.
- [x] Configure Oban in `config/config.exs`: set repo to `StockAnalysis.Repo`, define queues (`:sync` with concurrency 5, `:default` with concurrency 10).
- [x] Add `{Oban, Application.fetch_env!(:stock_analysis, Oban)}` to the supervision tree in `application.ex`.
- [x] Configure test env in `config/test.exs`: set `testing: :manual` so jobs don't run automatically during tests.
- [x] Verify `mix test` still passes and Oban tables exist after `mix ecto.migrate`.

### Acceptance criteria
- Oban is installed and configured with at least one queue.
- `oban_jobs` table exists in the database after migration.
- Supervision tree starts Oban without errors.
- Test environment uses manual testing mode (jobs don't auto-execute).

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Run `mix ecto.migrate` | `oban_jobs` table created |
| 2 | Start Phoenix server | No Oban-related errors in logs |
| 3 | Run `mix test` | All existing tests pass; Oban is in manual mode |
| 4 | Check `Oban.config()` in IEx | Shows configured queues and repo |

---

## M6-002: Ecto migrations and schemas

### Ticket
**ID**: M6-002  
**Title**: Ecto migrations and schemas — tickers, price_snapshots, score_snapshots

### Description (why this ticket is needed)
Three new tables store the historical data: `tickers` holds the master list of tracked symbols with metadata (name, sector, market cap); `price_snapshots` stores one row per ticker per day with OHLCV data; `score_snapshots` stores one row per ticker per day with all computed analysis scores. These tables let the app serve historical charts and trend analysis from Postgres instead of repeatedly hitting external APIs.

### Required tasks
- [x] Create migration for `tickers` table: `symbol` (string, unique index), `name` (string), `sector` (string, nullable), `market_cap` (bigint, nullable), `is_active` (boolean, default true), timestamps.
- [x] Create migration for `price_snapshots` table: `ticker_id` (references tickers), `date` (date), `open` (decimal), `high` (decimal), `low` (decimal), `close` (decimal), `volume` (bigint), timestamps. Unique index on `(ticker_id, date)`.
- [x] Create migration for `score_snapshots` table: `ticker_id` (references tickers), `date` (date), `technical_score` (float, nullable), `fundamental_score` (float, nullable), `sentiment_score` (float, nullable), `smart_money_score` (float, nullable), `recommendation_score` (float, nullable), `recommendation_label` (string, nullable), `confidence` (float, nullable), timestamps. Unique index on `(ticker_id, date)`.
- [x] Create Ecto schemas: `StockAnalysis.Market.Ticker`, `StockAnalysis.Market.PriceSnapshot`, `StockAnalysis.Market.ScoreSnapshot` with appropriate changesets and validations.
- [ ] Run `mix ecto.migrate` and verify tables exist.

### Acceptance criteria
- All three tables exist with correct columns, types, and indexes.
- Ecto schemas have `changeset/2` functions with validations.
- Unique indexes prevent duplicate entries per ticker+date.
- Foreign keys enforce referential integrity from snapshots to tickers.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Run `mix ecto.migrate` | Tables created without errors |
| 2 | Insert a ticker via IEx | Row created with timestamps |
| 3 | Insert two price_snapshots for same ticker+date | Second insert fails (unique constraint) |
| 4 | Insert a price_snapshot referencing non-existent ticker_id | Foreign key error |

---

## M6-003: Market context module

### Ticket
**ID**: M6-003  
**Title**: Market context module — queries, inserts, and historical lookups

### Description (why this ticket is needed)
The Market context (`StockAnalysis.Market`) provides the public API for reading and writing ticker and snapshot data. Controllers and workers use this module instead of calling Repo directly. It encapsulates queries like "get 30-day price history for AAPL" and insert/upsert operations that the background workers call.

### Required tasks
- [x] Create `StockAnalysis.Market` context module.
- [x] Implement `upsert_ticker(attrs)`: insert or update ticker by symbol; return `{:ok, ticker}`.
- [x] Implement `get_ticker(symbol)`: find ticker by symbol; return `{:ok, ticker}` or `{:error, :not_found}`.
- [x] Implement `list_active_tickers()`: return all tickers where `is_active == true`.
- [x] Implement `insert_price_snapshots(ticker_id, list_of_attrs)`: bulk insert price snapshots; use `on_conflict: :nothing` to skip duplicates.
- [x] Implement `insert_score_snapshot(ticker_id, date, scores_map)`: insert or update score snapshot for given date.
- [x] Implement `get_price_history(symbol, days \\ 30)`: return list of price_snapshots for ticker, ordered by date descending, limited to N days.
- [x] Implement `get_score_history(symbol, days \\ 30)`: return list of score_snapshots for ticker, ordered by date descending, limited to N days.
- [x] Write ExUnit tests for all context functions using the test database.

### Acceptance criteria
- All CRUD and query functions work correctly.
- Upsert operations are idempotent (re-running does not create duplicates).
- History queries respect the day limit and return data in correct order.
- All functions are covered by tests.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | `upsert_ticker(%{symbol: "AAPL", name: "Apple"})` twice | Same row returned both times |
| 2 | Insert 60 price snapshots; call `get_price_history("AAPL", 30)` | Returns 30 most recent rows |
| 3 | `insert_score_snapshot` for same ticker+date twice | Updates existing row (no duplicate) |
| 4 | `list_active_tickers()` with mix of active/inactive | Only active tickers returned |
| 5 | Run `mix test test/stock_analysis/market_test.exs` | All tests pass |

---

## M6-004: FMP bulk endpoints

### Ticket
**ID**: M6-004  
**Title**: FMP bulk endpoints — bulk quote and S&P 500 constituents

### Description (why this ticket is needed)
Financial Modeling Prep (FMP) offers bulk endpoints that return data for many tickers in a single API call, which is far more efficient than calling per-ticker endpoints when seeding or refreshing the entire universe. The bulk quote endpoint returns current price data for all tickers at once; the S&P 500 constituents endpoint provides the list of symbols to track.

### Required tasks
- [x] Add `get_sp500_constituents/0` to `StockAnalysis.Integrations.FMP`: calls `GET /api/v3/sp500_constituent` and returns list of `%{symbol, name, sector, ...}`.
- [x] Add `get_bulk_quote/0` to `StockAnalysis.Integrations.FMP`: calls `GET /api/v3/stock/full/real-time-price` (or equivalent bulk endpoint) and returns list of `%{symbol, price, volume, ...}`.
- [x] Normalize responses to match the shapes needed by the Market context (ticker upsert and price snapshot insert).
- [x] Add appropriate caching (constituents: 7-day TTL; bulk quote: 15-minute TTL).
- [x] Add Bypass-based tests for both endpoints.

### Acceptance criteria
- `get_sp500_constituents/0` returns ~500 symbols with name and sector.
- `get_bulk_quote/0` returns current price data for tracked tickers.
- Both endpoints handle API errors gracefully (rate limit, timeout).
- Cached to avoid excessive API calls.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Call `get_sp500_constituents()` with mock | Returns list of ~500 maps with symbol, name, sector |
| 2 | Call `get_bulk_quote()` with mock | Returns list of maps with symbol, price, volume |
| 3 | Call again within TTL | Returns cached data (no HTTP call) |
| 4 | Simulate API error | Returns `{:error, reason}` without crash |

---

## M6-005: Oban workers

### Ticket
**ID**: M6-005  
**Title**: Oban workers — SeedTickersJob, PriceSnapshotJob, ScoreSnapshotJob

### Description (why this ticket is needed)
Background workers automate data collection on a schedule. `SeedTickersJob` refreshes the ticker universe (weekly). `PriceSnapshotJob` captures daily OHLCV data for all active tickers. `ScoreSnapshotJob` computes and stores all analysis scores for each ticker daily. Together, they build the historical dataset without any manual intervention.

### Required tasks
- [x] Create `StockAnalysis.Workers.SeedTickersJob` (Oban worker, `:sync` queue):
  - Fetches S&P 500 constituents via FMP.
  - Upserts each into the `tickers` table via `Market.upsert_ticker/1`.
  - Scheduled weekly (e.g. every Sunday at 00:00 UTC) via Oban cron.
- [x] Create `StockAnalysis.Workers.PriceSnapshotJob` (Oban worker, `:sync` queue):
  - For each active ticker, fetch current price data (via FMP bulk quote or Alpha Vantage daily).
  - Insert into `price_snapshots` via `Market.insert_price_snapshots/2`.
  - Scheduled daily at market close + 1 hour (e.g. 21:00 UTC for US markets).
  - Rate-limit aware: batch tickers and pause between batches if needed.
- [x] Create `StockAnalysis.Workers.ScoreSnapshotJob` (Oban worker, `:sync` queue):
  - For each active ticker, compute scores using `Recommendation.compute/1` (or `compute_from_cache/1` if data is already cached).
  - Insert into `score_snapshots` via `Market.insert_score_snapshot/3`.
  - Scheduled daily after `PriceSnapshotJob` completes (e.g. 22:00 UTC).
- [x] Configure Oban crontab in `config/config.exs` with the schedules above.
- [x] Add unique job constraints to prevent duplicate concurrent runs.
- [x] Write ExUnit tests for each worker using `Oban.Testing`.

### Acceptance criteria
- `SeedTickersJob` populates ~500 tickers from FMP.
- `PriceSnapshotJob` creates one price_snapshot per active ticker per day.
- `ScoreSnapshotJob` creates one score_snapshot per active ticker per day.
- Jobs run on schedule and do not duplicate.
- Workers handle partial failures gracefully (one ticker failing doesn't stop the rest).

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Manually enqueue `SeedTickersJob`; check `tickers` table | ~500 rows inserted/updated |
| 2 | Manually enqueue `PriceSnapshotJob`; check `price_snapshots` | One row per active ticker for today |
| 3 | Manually enqueue `ScoreSnapshotJob`; check `score_snapshots` | One row per active ticker for today |
| 4 | Enqueue same job twice simultaneously | Only one executes (unique constraint) |
| 5 | Simulate FMP error for one ticker in batch | Other tickers still processed; error logged |
| 6 | Run `mix test` for worker tests | All pass with Oban testing mode |

---

## M6-006: History API endpoints and TypeScript types

### Ticket
**ID**: M6-006  
**Title**: History API endpoints, TypeScript types, and api-client methods

### Description (why this ticket is needed)
The web and mobile apps need HTTP endpoints to fetch historical price and score data so they can render trend charts and historical analysis views. Shared TypeScript types and api-client methods ensure both frontends consume the data consistently.

### Required tasks
- [x] Add Phoenix routes and controller actions:
  - `GET /api/stocks/:ticker/price-history?days=30` — returns array of `{date, open, high, low, close, volume}`.
  - `GET /api/stocks/:ticker/score-history?days=30` — returns array of `{date, technical_score, fundamental_score, sentiment_score, smart_money_score, recommendation_score, recommendation_label, confidence}`.
- [x] Controller fetches data via `StockAnalysis.Market` context; returns 404 if ticker not found.
- [x] Add TypeScript types in `@repo/types`:
  - `PriceSnapshot`: `{ date: string; open: number; high: number; low: number; close: number; volume: number }`.
  - `ScoreSnapshot`: `{ date: string; technical_score: number | null; fundamental_score: number | null; sentiment_score: number | null; smart_money_score: number | null; recommendation_score: number | null; recommendation_label: string | null; confidence: number | null }`.
- [x] Add api-client methods:
  - `getPriceHistory(ticker: string, days?: number): Promise<PriceSnapshot[]>`.
  - `getScoreHistory(ticker: string, days?: number): Promise<ScoreSnapshot[]>`.
- [x] Export new types from `@repo/types/src/index.ts`.

### Acceptance criteria
- Both endpoints return correct JSON arrays ordered by date descending.
- `days` query parameter defaults to 30 and is respected.
- 404 returned for unknown tickers.
- TypeScript types and api-client methods are available for web and mobile.

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | `GET /api/stocks/AAPL/price-history` (with seeded data) | 200, array of price snapshots |
| 2 | `GET /api/stocks/AAPL/price-history?days=7` | 200, at most 7 entries |
| 3 | `GET /api/stocks/INVALID/price-history` | 404 |
| 4 | `GET /api/stocks/AAPL/score-history` | 200, array of score snapshots |
| 5 | Call `api.getPriceHistory("AAPL")` from TypeScript | Returns typed array |

---

## M6-007: Seed S&P 500 tickers and backfill initial price data

### Ticket
**ID**: M6-007  
**Title**: Seed S&P 500 tickers and backfill initial price data

### Description (why this ticket is needed)
Once the infrastructure is in place, the database needs to be populated with an initial set of tickers and at least a few days of historical price data. This ticket provides a mix task that runs the seeding process manually (outside of Oban schedules) so the app has data from day one. It also serves as a verification that the full pipeline works end-to-end.

### Required tasks
- [x] Create `mix mnml.seed_tickers` task: calls `SeedTickersJob.perform/1` logic to fetch and upsert S&P 500 constituents.
- [x] Create `mix mnml.backfill_prices` task: for each active ticker, fetch recent daily prices (e.g. last 30 days from FMP historical endpoint or Alpha Vantage TIME_SERIES_DAILY) and insert into `price_snapshots`.
- [x] Add rate-limiting logic to backfill task: batch tickers (e.g. 5 at a time), pause between batches to respect API limits.
- [x] Document both tasks in README or a `docs/` file: what they do, when to run them, expected runtime.
- [ ] Verify end-to-end: after running both tasks, `GET /api/stocks/AAPL/price-history` returns data.

### Acceptance criteria
- `mix mnml.seed_tickers` populates ~500 rows in `tickers` table.
- `mix mnml.backfill_prices` populates price_snapshots for active tickers with at least 30 days of data.
- API endpoints return the seeded data.
- Tasks are idempotent (safe to re-run without creating duplicates).

### Test plan
| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | Run `mix mnml.seed_tickers` | `tickers` table has ~500 rows |
| 2 | Run `mix mnml.seed_tickers` again | No duplicates; same row count |
| 3 | Run `mix mnml.backfill_prices` | `price_snapshots` table populated |
| 4 | `GET /api/stocks/AAPL/price-history` | Returns 30 data points |
| 5 | Run `mix mnml.backfill_prices` again | No duplicates; idempotent |

---

## Milestone 6 completion checklist

- [x] M6-001: Oban dependency and configuration
- [x] M6-002: Ecto migrations and schemas
- [x] M6-003: Market context module
- [x] M6-004: FMP bulk endpoints
- [x] M6-005: Oban workers (seed, price, score)
- [x] M6-006: History API endpoints and TypeScript types
- [x] M6-007: Seed and backfill initial data

**Done when**: Oban is running in the supervision tree; tickers, price_snapshots, and score_snapshots tables exist and are populated; background workers refresh data on schedule; history API endpoints serve stored data to web and mobile; S&P 500 tickers are seeded with at least 30 days of price history.

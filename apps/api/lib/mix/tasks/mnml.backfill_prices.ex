defmodule Mix.Tasks.Mnml.BackfillPrices do
  @shortdoc "Backfills the last 30 days of daily price data for all active tickers"

  @moduledoc """
  Fetches the last 30 days of daily OHLCV price data for all active tickers
  and inserts rows into `price_snapshots`.

  ## Usage

      mix mnml.backfill_prices
      mix mnml.backfill_prices --days 90

  ## Options

    * `--days N` — number of days to backfill (default: 30, max: 365)

  ## When to run

  Run once after `mix mnml.seed_tickers` to populate initial price history.
  The daily Oban cron job (`PriceSnapshotJob`) keeps data fresh going forward,
  but cannot populate historical data before the job was first deployed.

  ## Expected runtime

  Approximately `ceil(ticker_count / 5) * 12` seconds due to Massive.com's
  5 requests/minute free-tier rate limit (e.g. ~500 tickers ≈ 20 minutes).
  For a paid Massive.com plan, you can increase `@batch_size` in
  `PriceSnapshotJob` to finish faster.

  ## Idempotency

  Safe to re-run. Existing price rows are skipped (`on_conflict: :nothing`).
  """

  use Mix.Task

  require Logger

  alias StockAnalysis.Market
  alias StockAnalysis.Repo
  alias StockAnalysis.Integrations.Massive

  # Massive.com free tier: 5 requests/minute
  @batch_size 5
  @batch_pause_ms 12_000

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    days = parse_days_arg(args)
    tickers = Market.list_active_tickers()

    if tickers == [] do
      Mix.shell().info("No active tickers found. Run `mix mnml.seed_tickers` first.")
      exit(:normal)
    end

    Mix.shell().info("Backfilling #{days} days of price data for #{length(tickers)} tickers...")
    Mix.shell().info("Estimated time: ~#{ceil(length(tickers) / @batch_size) * div(@batch_pause_ms, 1000)} seconds")

    {ok_count, err_count} =
      tickers
      |> Enum.chunk_every(@batch_size)
      |> Enum.with_index()
      |> Enum.reduce({0, 0}, fn {batch, idx}, {ok_acc, err_acc} ->
        if idx > 0, do: :timer.sleep(@batch_pause_ms)

        results = Enum.map(batch, &backfill_ticker(&1, days))
        ok = Enum.count(results, fn r -> r == :ok end)
        err = length(results) - ok
        {ok_acc + ok, err_acc + err}
      end)

    total = Repo.aggregate(StockAnalysis.Market.PriceSnapshot, :count)
    Mix.shell().info("Done. #{ok_count} tickers processed, #{err_count} errors. #{total} total price rows in database.")
  end

  defp backfill_ticker(ticker, days) do
    case Massive.get_daily(ticker.symbol) do
      {:ok, daily_data} ->
        cutoff = Date.add(Date.utc_today(), -days)

        snapshots =
          daily_data
          |> Enum.map(fn bar ->
            date = parse_date(bar.date)
            {date, %{date: date, open: bar.open, high: bar.high, low: bar.low, close: bar.close, volume: bar.volume}}
          end)
          |> Enum.filter(fn {date, _} -> Date.compare(date, cutoff) != :lt end)
          |> Enum.map(&elem(&1, 1))

        Market.insert_price_snapshots(ticker.id, snapshots)
        Logger.info("[backfill_prices] #{ticker.symbol}: #{length(snapshots)} rows")
        :ok

      {:error, :rate_limit} ->
        Logger.warning("[backfill_prices] rate limit hit for #{ticker.symbol}")
        :error

      {:error, reason} ->
        Logger.warning("[backfill_prices] failed #{ticker.symbol}: #{inspect(reason)}")
        :error
    end
  end

  defp parse_days_arg(args) do
    case OptionParser.parse(args, strict: [days: :integer]) do
      {[days: n], _, _} when n > 0 -> min(n, 365)
      _ -> 30
    end
  end

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> Date.utc_today()
    end
  end

  defp parse_date(date), do: date
end

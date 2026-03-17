defmodule StockAnalysis.Workers.PriceSnapshotJob do
  @moduledoc """
  Oban worker that captures daily OHLCV price data for all active tickers and
  inserts rows into `price_snapshots`.

  Scheduled daily at 21:00 UTC (one hour after US market close at 20:00 UTC).
  Batches tickers with a pause between batches to respect Alpha Vantage's
  5 requests/minute free-tier limit.
  """
  use Oban.Worker,
    queue: :sync,
    max_attempts: 3,
    unique: [period: 3600]

  require Logger

  alias StockAnalysis.Market
  alias StockAnalysis.Integrations.AlphaVantage

  # Alpha Vantage free tier: 5 requests/minute
  @batch_size 5
  @batch_pause_ms 12_000

  @impl Oban.Worker
  def perform(_job) do
    tickers = Market.list_active_tickers()
    date = Date.utc_today()
    Logger.info("[PriceSnapshotJob] processing #{length(tickers)} tickers for #{date}")

    tickers
    |> Enum.chunk_every(@batch_size)
    |> Enum.with_index()
    |> Enum.each(fn {batch, idx} ->
      if idx > 0, do: :timer.sleep(@batch_pause_ms)
      Enum.each(batch, &fetch_and_store(&1, date))
    end)

    :ok
  end

  defp fetch_and_store(ticker, date) do
    case AlphaVantage.get_daily(ticker.symbol) do
      {:ok, daily_data} ->
        # Use today's bar if available, otherwise fall back to most recent
        bar =
          Enum.find(daily_data, List.first(daily_data), fn b ->
            b.date == Date.to_iso8601(date)
          end)

        if bar do
          Market.insert_price_snapshots(ticker.id, [build_snapshot_attrs(bar)])
        end

      {:error, :rate_limit} ->
        Logger.warning("[PriceSnapshotJob] rate limit for #{ticker.symbol}, skipping")

      {:error, reason} ->
        Logger.warning("[PriceSnapshotJob] failed #{ticker.symbol}: #{inspect(reason)}")
    end
  end

  defp build_snapshot_attrs(bar) do
    %{
      date: parse_date(bar.date),
      open: bar.open,
      high: bar.high,
      low: bar.low,
      close: bar.close,
      volume: bar.volume
    }
  end

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> Date.utc_today()
    end
  end

  defp parse_date(date), do: date
end

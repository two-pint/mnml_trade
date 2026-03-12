defmodule StockAnalysis.Workers.SeedTickersJob do
  @moduledoc """
  Oban worker that fetches the current S&P 500 constituent list from FMP and
  upserts each symbol into the `tickers` table.

  Scheduled weekly on Sunday at 00:00 UTC. Safe to run manually at any time —
  upserts are idempotent.
  """
  use Oban.Worker,
    queue: :sync,
    max_attempts: 3,
    unique: [period: 3600]

  require Logger

  alias StockAnalysis.Market
  alias StockAnalysis.Integrations.FMP

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("[SeedTickersJob] starting S&P 500 ticker seed")

    case FMP.get_sp500_constituents() do
      {:ok, constituents} ->
        results =
          Enum.map(constituents, fn c ->
            Market.upsert_ticker(%{
              symbol: c.symbol,
              name: c.name || c.symbol,
              sector: c.sector
            })
          end)

        ok_count = Enum.count(results, fn {status, _} -> status == :ok end)
        err_count = length(results) - ok_count
        Logger.info("[SeedTickersJob] upserted #{ok_count} tickers, #{err_count} errors")
        :ok

      {:error, reason} ->
        Logger.error("[SeedTickersJob] failed to fetch S&P 500 constituents: #{inspect(reason)}")
        {:error, reason}
    end
  end
end

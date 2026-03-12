defmodule StockAnalysis.Workers.RefreshStockData do
  @moduledoc """
  Oban worker that refreshes cached data for a single ticker.

  Calls each context's fetch function which will update the ETS cache.
  Staggered by 2s between API calls to respect rate limits.
  """
  use Oban.Worker,
    queue: :data_refresh,
    max_attempts: 3,
    unique: [period: 60, keys: [:ticker]]

  alias StockAnalysis.Stocks
  alias StockAnalysis.Analysis
  alias StockAnalysis.Sentiment
  alias StockAnalysis.InstitutionalActivity

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"ticker" => ticker}}) do
    Logger.info("[RefreshStockData] refreshing #{ticker}")

    results =
      [
        {"overview", fn -> Stocks.get_overview(ticker) end},
        {"technical", fn -> Analysis.get_technical(ticker) end},
        {"fundamental", fn -> Analysis.get_fundamental(ticker) end},
        {"sentiment", fn -> Sentiment.get_sentiment(ticker) end},
        {"institutional", fn -> InstitutionalActivity.get_basic(ticker) end}
      ]
      |> Enum.reduce(%{ok: 0, skipped: 0, errors: []}, fn {label, fun}, acc ->
        case fun.() do
          {:ok, _} ->
            Process.sleep(2_000)
            %{acc | ok: acc.ok + 1}

          {:error, :rate_limit} ->
            Logger.warning("[RefreshStockData] #{ticker}/#{label} rate limited, stopping early")
            %{acc | skipped: acc.skipped + 1}

          {:error, reason} ->
            Logger.warning("[RefreshStockData] #{ticker}/#{label} failed: #{inspect(reason)}")
            %{acc | errors: [label | acc.errors]}
        end
      end)

    Logger.info(
      "[RefreshStockData] #{ticker} done: #{results.ok} ok, #{results.skipped} skipped, #{length(results.errors)} errors"
    )

    :ok
  end
end

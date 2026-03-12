defmodule StockAnalysis.Workers.ScheduleRefresh do
  @moduledoc """
  Oban cron worker that gathers high-priority tickers and enqueues
  RefreshStockData jobs for each, staggered to respect rate limits.

  Runs every 30min during market hours (Mon-Fri 8-16 ET) and every
  2h off-hours. High-priority tickers are the union of all user
  watchlists plus the static trending set.
  """
  use Oban.Worker,
    queue: :data_refresh,
    max_attempts: 1,
    unique: [period: 120]

  import Ecto.Query
  alias StockAnalysis.Repo
  alias StockAnalysis.Engagement.WatchlistItem

  @trending_tickers ~w(AAPL MSFT GOOGL AMZN NVDA)

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    period = Map.get(args, "period", "market")
    Logger.info("[ScheduleRefresh] running for period=#{period}")

    tickers = priority_tickers()
    Logger.info("[ScheduleRefresh] enqueuing #{length(tickers)} tickers")

    tickers
    |> Enum.with_index()
    |> Enum.each(fn {ticker, idx} ->
      StockAnalysis.Workers.RefreshStockData.new(
        %{ticker: ticker},
        schedule_in: idx * 15
      )
      |> Oban.insert()
    end)

    :ok
  end

  defp priority_tickers do
    watchlist_tickers =
      WatchlistItem
      |> select([w], w.ticker)
      |> distinct(true)
      |> Repo.all()

    (@trending_tickers ++ watchlist_tickers)
    |> Enum.map(&String.upcase/1)
    |> Enum.uniq()
  end
end

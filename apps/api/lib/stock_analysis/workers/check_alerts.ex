defmodule StockAnalysis.Workers.CheckAlerts do
  @moduledoc """
  Oban worker that checks watchlist tickers for alert conditions
  (price movement, unusual whale activity) and sends push notifications
  to users who have those tickers on their watchlist.
  """
  use Oban.Worker,
    queue: :data_refresh,
    max_attempts: 2,
    unique: [period: 300]

  import Ecto.Query
  alias StockAnalysis.Repo
  alias StockAnalysis.Engagement.WatchlistItem
  alias StockAnalysis.Notifications
  alias StockAnalysis.Stocks

  require Logger

  @price_change_threshold 5.0

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("[CheckAlerts] scanning watchlist tickers for alerts")

    tickers_with_users =
      WatchlistItem
      |> select([w], {w.ticker, w.user_id})
      |> Repo.all()
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    Enum.each(tickers_with_users, fn {ticker, user_ids} ->
      check_ticker_alerts(ticker, user_ids)
      Process.sleep(2_000)
    end)

    :ok
  end

  defp check_ticker_alerts(ticker, user_ids) do
    case Stocks.get_overview(ticker) do
      {:ok, overview} ->
        change_pct = parse_change_percent(overview[:change_percent])

        if abs(change_pct) >= @price_change_threshold do
          direction = if change_pct > 0, do: "up", else: "down"
          title = "#{ticker} #{direction} #{abs(change_pct) |> Float.round(1)}%"
          body = "$#{overview[:price]} (#{overview[:change_percent]})"

          Enum.each(user_ids, fn user_id ->
            case Notifications.get_preferences(user_id) do
              {:ok, %{"price_alerts" => true}} ->
                Notifications.send_push(user_id, title, body, %{
                  type: "price_alert",
                  ticker: ticker
                })

              _ ->
                :ok
            end
          end)
        end

      {:error, _} ->
        Logger.debug("[CheckAlerts] could not fetch overview for #{ticker}")
    end
  end

  defp parse_change_percent(nil), do: 0.0

  defp parse_change_percent(pct) when is_binary(pct) do
    pct
    |> String.replace("%", "")
    |> String.trim()
    |> Float.parse()
    |> case do
      {val, _} -> val
      :error -> 0.0
    end
  end

  defp parse_change_percent(pct) when is_number(pct), do: pct / 1
  defp parse_change_percent(_), do: 0.0
end

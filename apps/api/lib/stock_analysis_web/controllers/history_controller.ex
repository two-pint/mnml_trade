defmodule StockAnalysisWeb.HistoryController do
  use StockAnalysisWeb, :controller

  alias StockAnalysis.Market

  @max_days 365

  def price_history(conn, %{"ticker" => ticker} = params) do
    days = parse_days(params["days"])

    case Market.get_price_history(ticker, days) do
      {:ok, history} ->
        conn
        |> put_status(:ok)
        |> json(Enum.map(history, &format_price_snapshot/1))

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Ticker not found"})
    end
  end

  def score_history(conn, %{"ticker" => ticker} = params) do
    days = parse_days(params["days"])

    case Market.get_score_history(ticker, days) do
      {:ok, history} ->
        conn
        |> put_status(:ok)
        |> json(Enum.map(history, &format_score_snapshot/1))

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Ticker not found"})
    end
  end

  defp parse_days(nil), do: 30

  defp parse_days(days) when is_binary(days) do
    case Integer.parse(days) do
      {n, _} when n > 0 -> min(n, @max_days)
      _ -> 30
    end
  end

  defp parse_days(_), do: 30

  defp format_price_snapshot(s) do
    %{
      date: Date.to_iso8601(s.date),
      open: s.open,
      high: s.high,
      low: s.low,
      close: s.close,
      volume: s.volume
    }
  end

  defp format_score_snapshot(s) do
    %{
      date: Date.to_iso8601(s.date),
      technical_score: s.technical_score,
      fundamental_score: s.fundamental_score,
      sentiment_score: s.sentiment_score,
      smart_money_score: s.smart_money_score,
      recommendation_score: s.recommendation_score,
      recommendation_label: s.recommendation_label,
      confidence: s.confidence
    }
  end
end

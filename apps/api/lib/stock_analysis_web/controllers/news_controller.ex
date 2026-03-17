defmodule StockAnalysisWeb.NewsController do
  @moduledoc """
  Serves market-wide and ticker-specific news (Finnhub).
  """
  use StockAnalysisWeb, :controller

  alias StockAnalysis.Integrations.Finnhub

  def market(conn, _params) do
    case Finnhub.get_market_news() do
      {:ok, articles} ->
        conn
        |> put_status(:ok)
        |> json(articles)

      {:error, :rate_limit} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "service_unavailable", message: "News temporarily unavailable"})

      {:error, :api_key_missing} ->
        conn
        |> put_status(:ok)
        |> json([])

      {:error, _} ->
        conn
        |> put_status(:ok)
        |> json([])
    end
  end
end

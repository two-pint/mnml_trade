defmodule StockAnalysisWeb.StocksController do
  use StockAnalysisWeb, :controller

  alias StockAnalysis.Stocks

  def search(conn, params) do
    q = params["q"] || ""
    case Stocks.search(q) do
      {:ok, results} ->
        conn
        |> put_status(:ok)
        |> json(results)

      {:error, :rate_limit} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "service_unavailable", message: "Search temporarily unavailable"})

      {:error, reason} when reason in [:server_error, :invalid_response, :api_key_missing] ->
        conn
        |> put_status(:bad_gateway)
        |> json(%{error: "bad_gateway", message: "Search service error"})

      {:error, _reason} ->
        # :not_found or other — degrade gracefully with empty results
        conn
        |> put_status(:ok)
        |> json([])
    end
  end

  def show(conn, %{"ticker" => ticker}) do
    case Stocks.get_overview(ticker) do
      {:ok, overview} ->
        conn
        |> put_status(:ok)
        |> json(overview)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Stock not found"})
    end
  end
end

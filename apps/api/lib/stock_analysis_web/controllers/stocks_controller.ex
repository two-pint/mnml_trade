defmodule StockAnalysisWeb.StocksController do
  use StockAnalysisWeb, :controller

  alias StockAnalysis.Analysis
  alias StockAnalysis.InstitutionalActivity
  alias StockAnalysis.Stocks

  def trending(conn, _params) do
    case Stocks.get_trending() do
      {:ok, list} ->
        conn
        |> put_status(:ok)
        |> json(list)

      {:error, _} ->
        conn
        |> put_status(:ok)
        |> json([])
    end
  end

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

  def institutional(conn, %{"ticker" => ticker}) do
    case InstitutionalActivity.get_basic(ticker) do
      {:ok, data} ->
        conn
        |> put_status(:ok)
        |> json(data)

      {:error, :rate_limit} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "service_unavailable", message: "Institutional data temporarily unavailable"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Institutional data not found"})
    end
  end

  def daily(conn, %{"ticker" => ticker}) do
    case Stocks.get_daily(ticker) do
      {:ok, series} ->
        conn
        |> put_status(:ok)
        |> json(series)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Stock not found"})
    end
  end

  def technical(conn, %{"ticker" => ticker}) do
    case Analysis.get_technical(ticker) do
      {:ok, technical} ->
        conn
        |> put_status(:ok)
        |> json(technical)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Stock not found"})
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

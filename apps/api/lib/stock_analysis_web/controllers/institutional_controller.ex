defmodule StockAnalysisWeb.InstitutionalController do
  use StockAnalysisWeb, :controller

  alias StockAnalysis.InstitutionalActivity

  def congressional(conn, %{"ticker" => ticker}) do
    case InstitutionalActivity.get_congressional(ticker) do
      {:ok, data} ->
        conn |> put_status(:ok) |> json(data)

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found", message: "Congressional data not found"})
    end
  end

  def insider_trades(conn, %{"ticker" => ticker}) do
    case InstitutionalActivity.get_insider_trades(ticker) do
      {:ok, data} ->
        conn |> put_status(:ok) |> json(data)

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found", message: "Insider data not found"})
    end
  end

  def holdings(conn, %{"ticker" => ticker}) do
    case InstitutionalActivity.get_holdings(ticker) do
      {:ok, data} ->
        conn |> put_status(:ok) |> json(data)

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found", message: "Holdings data not found"})
    end
  end

  def market_tide(conn, _params) do
    case InstitutionalActivity.get_market_tide() do
      {:ok, data} ->
        conn |> put_status(:ok) |> json(data)

      {:error, _} ->
        conn |> put_status(:service_unavailable) |> json(%{error: "service_unavailable", message: "Market tide unavailable"})
    end
  end

  def smart_money_score(conn, %{"ticker" => ticker}) do
    case InstitutionalActivity.get_smart_money_score(ticker) do
      {:ok, data} ->
        conn |> put_status(:ok) |> json(data)

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found", message: "Smart money data not found"})
    end
  end
end

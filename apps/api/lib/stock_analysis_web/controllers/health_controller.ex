defmodule StockAnalysisWeb.HealthController do
  use StockAnalysisWeb, :controller

  def index(conn, _params) do
    case check_db() do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{status: "ok"})

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error", message: reason})
    end
  end

  defp check_db do
    case Ecto.Adapters.SQL.query(StockAnalysis.Repo, "SELECT 1") do
      {:ok, _result} -> :ok
      {:error, _error} -> {:error, "database unreachable"}
    end
  rescue
    _e -> {:error, "database unreachable"}
  end
end

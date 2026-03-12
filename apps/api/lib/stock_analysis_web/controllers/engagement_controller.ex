defmodule StockAnalysisWeb.EngagementController do
  use StockAnalysisWeb, :controller

  alias StockAnalysis.Engagement

  action_fallback StockAnalysisWeb.FallbackController

  def list_watchlist(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    items = Engagement.list_watchlist(user.id)

    conn
    |> put_status(:ok)
    |> render(:watchlist, items: items)
  end

  def add_to_watchlist(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, item} <- Engagement.add_to_watchlist(user.id, params) do
      conn
      |> put_status(:created)
      |> render(:watchlist_item, item: item)
    end
  end

  def remove_from_watchlist(conn, %{"ticker" => ticker}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, :removed} <- Engagement.remove_from_watchlist(user.id, ticker) do
      send_resp(conn, :no_content, "")
    end
  end

  def list_history(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    entries = Engagement.list_history(user.id)

    conn
    |> put_status(:ok)
    |> render(:history, entries: entries)
  end
end

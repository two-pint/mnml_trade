defmodule StockAnalysisWeb.NotificationsController do
  use StockAnalysisWeb, :controller

  alias StockAnalysis.Notifications

  action_fallback StockAnalysisWeb.FallbackController

  def register_token(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, token} <- Notifications.register_token(user.id, params) do
      conn
      |> put_status(:created)
      |> json(%{data: %{id: token.id, token: token.token, platform: token.platform}})
    end
  end

  def remove_token(conn, %{"token" => token}) do
    user = Guardian.Plug.current_resource(conn)
    Notifications.remove_token(user.id, token)
    send_resp(conn, :no_content, "")
  end

  def get_preferences(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, prefs} <- Notifications.get_preferences(user.id) do
      conn
      |> put_status(:ok)
      |> json(%{data: prefs})
    end
  end

  def update_preferences(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, user} <- Notifications.update_preferences(user.id, params) do
      conn
      |> put_status(:ok)
      |> json(%{data: user.notification_preferences})
    end
  end
end

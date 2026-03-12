defmodule StockAnalysisWeb.UserController do
  use StockAnalysisWeb, :controller

  alias StockAnalysis.Accounts

  action_fallback StockAnalysisWeb.FallbackController

  def me(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    conn
    |> put_status(:ok)
    |> json(%{
      id: user.id,
      email: user.email,
      username: user.username,
      email_verified: user.email_verified
    })
  end

  def update_profile(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, updated} <- Accounts.update_profile(user, params) do
      conn
      |> put_status(:ok)
      |> json(%{
        id: updated.id,
        email: updated.email,
        username: updated.username,
        email_verified: updated.email_verified
      })
    end
  end
end

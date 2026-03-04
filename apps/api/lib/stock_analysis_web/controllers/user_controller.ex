defmodule StockAnalysisWeb.UserController do
  use StockAnalysisWeb, :controller

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
end

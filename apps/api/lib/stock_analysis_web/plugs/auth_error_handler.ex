defmodule StockAnalysisWeb.Plugs.AuthErrorHandler do
  @behaviour Guardian.Plug.ErrorHandler

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, _reason}, _opts) do
    message =
      case type do
        :unauthenticated -> "Authentication required"
        :invalid_token -> "Invalid or expired token"
        _ -> "Unauthorized"
      end

    conn
    |> put_status(:unauthorized)
    |> json(%{error: to_string(type), message: message})
    |> halt()
  end
end

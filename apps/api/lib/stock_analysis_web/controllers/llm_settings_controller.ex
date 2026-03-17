defmodule StockAnalysisWeb.LlmSettingsController do
  use StockAnalysisWeb, :controller

  alias StockAnalysis.Accounts.UserLLMSettings

  action_fallback StockAnalysisWeb.FallbackController

  def get_settings(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    case UserLLMSettings.get_settings(user.id) do
      {:ok, settings} ->
        conn
        |> put_status(:ok)
        |> json(%{data: settings})

      {:error, :not_found} ->
        conn
        |> put_status(:ok)
        |> json(%{data: %{provider: nil, model: nil, api_key_configured: false}})
    end
  end

  def update_settings(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, settings} <- UserLLMSettings.put_settings(user.id, params) do
      conn
      |> put_status(:ok)
      |> json(%{data: settings})
    end
  end
end

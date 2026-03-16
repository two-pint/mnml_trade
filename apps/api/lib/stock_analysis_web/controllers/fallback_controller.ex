defmodule StockAnalysisWeb.FallbackController do
  use StockAnalysisWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: StockAnalysisWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "not_found", message: "Resource not found"})
  end

  @trade_errors %{
    insufficient_funds: "Insufficient cash balance for this trade",
    insufficient_shares: "Insufficient shares to sell",
    price_unavailable: "Unable to fetch current price for this ticker",
    invalid_ticker: "Ticker is required",
    invalid_side: "Side must be \"buy\" or \"sell\"",
    invalid_quantity: "Quantity must be between 1 and 10,000"
  }

  def call(conn, {:error, reason}) when is_map_key(@trade_errors, reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: to_string(reason), message: @trade_errors[reason]})
  end

  @llm_settings_errors %{
    invalid_provider: "Provider must be openai or anthropic",
    api_key_required: "API key is required when adding LLM settings",
    encryption_failed: "Failed to store API key securely"
  }

  def call(conn, {:error, reason}) when is_map_key(@llm_settings_errors, reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: to_string(reason), message: @llm_settings_errors[reason]})
  end

  def call(conn, {:error, :llm_not_configured}) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "llm_not_configured", message: "Add your API key in Settings to enable AI analysis."})
  end
end

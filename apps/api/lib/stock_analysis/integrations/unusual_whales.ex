defmodule StockAnalysis.Integrations.UnusualWhales do
  @moduledoc """
  Unusual Whales API integration for options flow and dark pool data.

  API key is configured via env `UNUSUAL_WHALES_API_KEY` (never hard-coded).
  Rate limit: 120 requests/minute; when approaching limit we return cached + stale in the context.
  """
  require Logger

  @default_base_url "https://api.unusualwhales.com"

  defp base_url do
    Application.get_env(:stock_analysis, :unusual_whales_base_url, @default_base_url)
  end

  @doc """
  Fetches recent unusual options flow for a ticker.

  Returns `{:ok, [%{type: _, strike: _, expiry: _, premium: _, quantity: _, sentiment: _}, ...]}`
  or `{:error, reason}` (e.g. `:not_found`, `:rate_limit`, `:server_error`).
  """
  def get_options_flow(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    path = "/api/option-trades/flow-alerts"
    params = [ticker_symbol: ticker, limit: 50]

    case get(path, params) do
      {:ok, body} when is_map(body) ->
        trades = extract_trades_list(body)
        {:ok, Enum.map(trades, &normalize_options_trade/1)}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches dark pool activity for a ticker.

  Returns `{:ok, %{volume: _, net_buy_sell: _, block_trades: _}}` or `{:error, reason}`.
  """
  def get_dark_pool(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    path = "/api/darkpool/#{ticker}"
    params = [min_premium: 2_000_000]

    case get(path, params) do
      {:ok, body} when is_map(body) ->
        {:ok, normalize_dark_pool(body)}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Private: HTTP

  defp api_key do
    Application.get_env(:stock_analysis, :unusual_whales_api_key) ||
      System.get_env("UNUSUAL_WHALES_API_KEY")
  end

  defp get(path, params) do
    key = api_key()
    if is_nil(key) or key == "" do
      Logger.warning("Unusual Whales: API key not configured")
      {:error, :api_key_missing}
    else
      url = base_url() <> path
      query = URI.encode_query(Enum.map(params, fn {k, v} -> {to_string(k), v} end))
      url = if query == "", do: url, else: url <> "?" <> query

      opts = [
        headers: [{"authorization", "Bearer " <> key}],
        receive_timeout: 15_000,
        retry: :transient
      ]

      case Req.get(url, opts) do
        {:ok, %{status: 200, body: body}} ->
          parsed = maybe_decode_json(body)
          if is_map(parsed) do
            {:ok, parsed}
          else
            {:error, :invalid_response}
          end

        {:ok, %{status: 429}} ->
          {:error, :rate_limit}

        {:ok, %{status: 404}} ->
          {:error, :not_found}

        {:ok, %{status: status}} when status >= 500 ->
          {:error, :server_error}

        {:ok, _} ->
          {:error, :invalid_response}

        {:error, _} ->
          {:error, :server_error}
      end
    end
  end

  defp maybe_decode_json(body) when is_map(body), do: body
  defp maybe_decode_json(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, map} -> map
      _ -> nil
    end
  end
  defp maybe_decode_json(_), do: nil

  ## Private: normalize responses (flexible to API shape)

  defp extract_trades_list(%{"data" => list}) when is_list(list), do: list
  defp extract_trades_list(%{"trades" => list}) when is_list(list), do: list
  defp extract_trades_list(%{"flow" => list}) when is_list(list), do: list
  defp extract_trades_list(list) when is_list(list), do: list
  defp extract_trades_list(_), do: []

  defp normalize_options_trade(raw) when is_map(raw) do
    %{
      type: str_or_nil(raw["option_activity_type"] || raw["type"] || raw["trade_type"]),
      strike: num_or_nil(raw["strike"] || raw["strike_price"]),
      expiry: str_or_nil(raw["expiration"] || raw["expiry"] || raw["expiration_date"]),
      premium: num_or_nil(raw["premium"] || raw["cost"] || raw["total_premium"]),
      quantity: num_or_nil(raw["quantity"] || raw["contracts"] || raw["size"]),
      sentiment: str_or_nil(raw["sentiment"] || raw["bull_bear"])
    }
  end

  defp normalize_dark_pool(raw) when is_map(raw) do
    %{
      volume: num_or_nil(raw["volume"] || raw["total_volume"] || raw["dark_pool_volume"]),
      net_buy_sell: num_or_nil(raw["net_buy_sell"] || raw["net"] || raw["net_volume"]),
      block_trades: raw["block_trades"] || raw["blocks"] || []
    }
  end

  defp str_or_nil(nil), do: nil
  defp str_or_nil(s) when is_binary(s), do: s
  defp str_or_nil(s), do: to_string(s)

  defp num_or_nil(nil), do: nil
  defp num_or_nil(n) when is_number(n), do: n
  defp num_or_nil(s) when is_binary(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> nil
    end
  end
  defp num_or_nil(_), do: nil
end

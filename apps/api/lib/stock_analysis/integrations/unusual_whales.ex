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

  @doc """
  Fetches congressional trades for a ticker (last 90 days).

  Returns `{:ok, [%{representative: _, transaction_type: _, amount: _, date: _, party: _}, ...]}`
  or `{:error, reason}`.
  """
  def get_congressional(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    path = "/api/congressional-trading/#{ticker}"

    case get(path, []) do
      {:ok, body} when is_map(body) ->
        trades = extract_list(body)
        {:ok, Enum.map(trades, &normalize_congressional/1)}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches insider trades for a ticker (last 90 days).

  Returns `{:ok, [%{insider_name: _, title: _, transaction_type: _, shares: _, price: _, date: _}, ...]}`
  or `{:error, reason}`.
  """
  def get_insider_trades(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    path = "/api/insider-trading/#{ticker}"

    case get(path, []) do
      {:ok, body} when is_map(body) ->
        trades = extract_list(body)
        {:ok, Enum.map(trades, &normalize_insider/1)}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches institutional holdings (13F) for a ticker.

  Returns `{:ok, [%{holder: _, shares: _, value: _, change: _, date: _}, ...]}`
  or `{:error, reason}`.
  """
  def get_institutional_holdings(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    path = "/api/institutional-holdings/#{ticker}"

    case get(path, []) do
      {:ok, body} when is_map(body) ->
        holdings = extract_list(body)
        {:ok, Enum.map(holdings, &normalize_holding/1)}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches overall market tide (market-wide sentiment indicator).

  Returns `{:ok, %{score: _, label: _, call_volume: _, put_volume: _, ratio: _}}`
  or `{:error, reason}`.
  """
  def get_market_tide do
    path = "/api/market/tide"

    case get(path, []) do
      {:ok, body} when is_map(body) ->
        {:ok, normalize_market_tide(body)}

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

  defp extract_list(%{"data" => list}) when is_list(list), do: list
  defp extract_list(%{"trades" => list}) when is_list(list), do: list
  defp extract_list(%{"holdings" => list}) when is_list(list), do: list
  defp extract_list(%{"results" => list}) when is_list(list), do: list
  defp extract_list(list) when is_list(list), do: list
  defp extract_list(_), do: []

  defp normalize_congressional(raw) when is_map(raw) do
    %{
      representative: str_or_nil(raw["representative"] || raw["name"] || raw["politician"]),
      transaction_type: str_or_nil(raw["transaction_type"] || raw["type"]),
      amount: str_or_nil(raw["amount"] || raw["range"]),
      date: str_or_nil(raw["transaction_date"] || raw["date"]),
      party: str_or_nil(raw["party"]),
      ticker: str_or_nil(raw["ticker"] || raw["symbol"])
    }
  end

  defp normalize_insider(raw) when is_map(raw) do
    %{
      insider_name: str_or_nil(raw["insider_name"] || raw["name"] || raw["owner"]),
      title: str_or_nil(raw["title"] || raw["relationship"]),
      transaction_type: str_or_nil(raw["transaction_type"] || raw["type"]),
      shares: num_or_nil(raw["shares"] || raw["quantity"]),
      price: num_or_nil(raw["price"] || raw["avg_price"]),
      value: num_or_nil(raw["value"] || raw["total_value"]),
      date: str_or_nil(raw["filing_date"] || raw["date"])
    }
  end

  defp normalize_holding(raw) when is_map(raw) do
    %{
      holder: str_or_nil(raw["holder"] || raw["institution"] || raw["name"]),
      shares: num_or_nil(raw["shares"] || raw["quantity"]),
      value: num_or_nil(raw["value"] || raw["market_value"]),
      change: num_or_nil(raw["change"] || raw["shares_change"]),
      change_percent: num_or_nil(raw["change_percent"] || raw["percent_change"]),
      date: str_or_nil(raw["date"] || raw["report_date"])
    }
  end

  defp normalize_market_tide(raw) when is_map(raw) do
    call_vol = num_or_nil(raw["call_volume"] || raw["calls"])
    put_vol = num_or_nil(raw["put_volume"] || raw["puts"])
    ratio = if call_vol && put_vol && put_vol > 0, do: Float.round(call_vol / put_vol, 2), else: nil

    score = num_or_nil(raw["score"] || raw["tide_score"])
    label =
      cond do
        is_number(score) and score > 60 -> "Bullish"
        is_number(score) and score < 40 -> "Bearish"
        is_number(score) -> "Neutral"
        true -> str_or_nil(raw["label"] || raw["sentiment"])
      end

    %{
      score: score,
      label: label,
      call_volume: call_vol,
      put_volume: put_vol,
      ratio: ratio
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

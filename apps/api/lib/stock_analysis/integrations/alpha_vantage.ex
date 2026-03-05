defmodule StockAnalysis.Integrations.AlphaVantage do
  @moduledoc """
  Alpha Vantage API integration for quotes, time series, and technical indicators.

  API key is configured via application env or `ALPHA_VANTAGE_API_KEY` (never hard-coded).
  Free tier: 5 requests/minute; rate-limit warnings are logged when approaching the limit.
  """
  require Logger

  @default_base_url "https://www.alphavantage.co/query"

  defp base_url do
    Application.get_env(:stock_analysis, :alpha_vantage_base_url, @default_base_url)
  end

  @doc """
  Fetches the current quote for a ticker.

  Returns `{:ok, %{symbol: _, price: _, change: _, change_percent: _, volume: _, ...}}`
  or `{:error, reason}` (e.g. `:not_found`, `:server_error`, `:rate_limit`, `:invalid_response`).
  """
  def get_quote(ticker) when is_binary(ticker) do
    case request("GLOBAL_QUOTE", symbol: ticker) do
      {:ok, %{"Global Quote" => quote}} when is_map(quote) and map_size(quote) > 0 ->
        {:ok, normalize_quote(quote)}

      {:ok, %{"Global Quote" => _}} ->
        {:error, :not_found}

      {:ok, %{"Error Message" => _}} ->
        {:error, :not_found}

      {:ok, %{"Note" => _}} ->
        {:error, :rate_limit}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches intraday time series (OHLCV) for a ticker.

  `interval` is e.g. `"1min"`, `"5min"`, `"15min"`, `"30min"`, `"60min"`.
  Returns `{:ok, [%{timestamp: _, open: _, high: _, low: _, close: _, volume: _}, ...]}`
  or `{:error, reason}`.
  """
  def get_intraday(ticker, interval) when is_binary(ticker) and is_binary(interval) do
    key = "Time Series (#{interval})"
    case request("TIME_SERIES_INTRADAY", symbol: ticker, interval: interval) do
      {:ok, %{^key => series}} when is_map(series) ->
        {:ok, normalize_ohlcv_series(series)}

      {:ok, %{"Error Message" => _}} ->
        {:error, :not_found}

      {:ok, %{"Note" => _}} ->
        {:error, :rate_limit}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches daily time series (OHLCV) for a ticker.

  Returns `{:ok, [%{date: _, open: _, high: _, low: _, close: _, volume: _}, ...]}`
  or `{:error, reason}`.
  """
  def get_daily(ticker) when is_binary(ticker) do
    case request("TIME_SERIES_DAILY", symbol: ticker) do
      {:ok, %{"Time Series (Daily)" => series}} when is_map(series) ->
        {:ok, normalize_ohlcv_series(series)}

      {:ok, %{"Error Message" => _}} ->
        {:error, :not_found}

      {:ok, %{"Note" => _}} ->
        {:error, :rate_limit}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Searches for symbols by keyword (ticker or name).

  Returns `{:ok, [%{ticker: _, name: _, type: _, region: _}, ...]}` or `{:error, reason}`.
  """
  def symbol_search(keywords) when is_binary(keywords) do
    case request("SYMBOL_SEARCH", keywords: keywords) do
      {:ok, %{"bestMatches" => matches}} when is_list(matches) ->
        {:ok, Enum.map(matches, &normalize_search_match/1)}

      {:ok, %{"Error Message" => _}} ->
        {:error, :not_found}

      {:ok, %{"Note" => _}} ->
        {:error, :rate_limit}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches a technical indicator series.

  `indicator` is e.g. `:rsi`, `:macd`, `:sma`, `:bbands`, `:atr`, `:adx`, `:stoch`.
  `params` is a map of optional params (e.g. `%{period: 14, series_type: "close"}`).

  Returns `{:ok, [%{date: _, value: _}, ...]}` or `{:ok, [%{date: _, value: _, ...}, ...]}`
  for multi-value indicators, or `{:error, reason}` (e.g. `:unsupported_indicator`).
  """
  @supported_indicators [:rsi, :macd, :sma, :bbands, :atr, :adx, :stoch]

  def get_technical_indicator(ticker, indicator, params \\ %{}) when is_binary(ticker) do
    if indicator in @supported_indicators do
      {function, series_key} = indicator_function_and_key(indicator)
      query_params =
        [symbol: ticker, interval: "daily", series_type: "close"]
        |> Keyword.merge(atomize_params(params))

      case request(function, query_params) do
        {:ok, %{^series_key => series}} when is_map(series) ->
          {:ok, normalize_indicator_series(series, indicator)}

        {:ok, %{"Error Message" => _}} ->
          {:error, :not_found}

        {:ok, %{"Note" => _}} ->
          {:error, :rate_limit}

        {:ok, _} ->
          {:error, :invalid_response}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :unsupported_indicator}
    end
  end

  ## Private: HTTP and normalization

  defp api_key do
    Application.get_env(:stock_analysis, :alpha_vantage_api_key) ||
      System.get_env("ALPHA_VANTAGE_API_KEY")
  end

  defp request(function, extra_params) do
    key = api_key()
    if is_nil(key) or key == "" do
      Logger.warning("Alpha Vantage: API key not configured")
      {:error, :api_key_missing}
    else
      params =
        [function: function, apikey: key]
        |> Keyword.merge(extra_params)
        |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)

      opts = [
        params: params,
        receive_timeout: 15_000,
        retry: :transient
      ]

      case Req.get(base_url(), opts) do
        {:ok, %{status: 200, body: body}} ->
          parsed = maybe_decode_json(body)
          if is_map(parsed) do
            maybe_log_rate_limit(parsed)
            {:ok, parsed}
          else
            {:error, :invalid_response}
          end

        {:ok, %{status: 429}} ->
          {:error, :rate_limit}

        {:ok, %{status: status}} when status >= 500 ->
          {:error, :server_error}

        {:ok, %{status: _}} ->
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

  defp maybe_log_rate_limit(%{"Note" => note}) do
    Logger.warning("Alpha Vantage rate limit: #{inspect(note)}")
  end
  defp maybe_log_rate_limit(_), do: :ok

  defp normalize_search_match(raw) when is_map(raw) do
    %{
      ticker: raw["1. symbol"] || raw["symbol"],
      name: raw["2. name"] || raw["name"],
      type: raw["3. type"] || raw["type"],
      region: raw["4. region"] || raw["region"]
    }
  end

  defp normalize_quote(raw) do
    %{
      symbol: raw["01. symbol"],
      open: parse_float(raw["02. open"]),
      high: parse_float(raw["03. high"]),
      low: parse_float(raw["04. low"]),
      price: parse_float(raw["05. price"]),
      volume: parse_int(raw["06. volume"]),
      latest_trading_day: raw["07. latest trading day"],
      previous_close: parse_float(raw["08. previous close"]),
      change: parse_float(raw["09. change"]),
      change_percent: raw["10. change percent"]
    }
  end

  defp normalize_ohlcv_series(series) do
    series
    |> Enum.map(fn {datetime, bar} ->
      %{
        timestamp: datetime,
        date: datetime,
        open: parse_float(bar["1. open"]),
        high: parse_float(bar["2. high"]),
        low: parse_float(bar["3. low"]),
        close: parse_float(bar["4. close"]),
        volume: parse_int(bar["5. volume"])
      }
    end)
    |> Enum.sort_by(fn %{timestamp: t} -> t end, :desc)
  end

  defp normalize_indicator_series(series, _indicator) do
    series
    |> Enum.map(fn {date, values} ->
      # Most indicators have a single value key (e.g. "RSI"); some have multiple (e.g. MACD)
      value =
        case Map.values(values) do
          [v] -> parse_float(v)
          many -> Enum.map(many, &parse_float/1)
        end
      %{date: date, value: value}
    end)
    |> Enum.sort_by(fn %{date: d} -> d end, :desc)
  end

  defp indicator_function_and_key(:rsi), do: {"RSI", "Technical Analysis: RSI"}
  defp indicator_function_and_key(:macd), do: {"MACD", "Technical Analysis: MACD"}
  defp indicator_function_and_key(:sma), do: {"SMA", "Technical Analysis: SMA"}
  defp indicator_function_and_key(:bbands), do: {"BBANDS", "Technical Analysis: BBANDS"}
  defp indicator_function_and_key(:atr), do: {"ATR", "Technical Analysis: ATR"}
  defp indicator_function_and_key(:adx), do: {"ADX", "Technical Analysis: ADX"}
  defp indicator_function_and_key(:stoch), do: {"STOCH", "Technical Analysis: STOCH"}

  defp parse_float(nil), do: nil
  defp parse_float(s) when is_binary(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> nil
    end
  end
  defp parse_float(_), do: nil

  defp parse_int(nil), do: nil
  defp parse_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {i, _} -> i
      :error -> nil
    end
  end
  defp parse_int(_), do: nil

  # Convert param map to keyword list for request (period -> "period", etc.)
  defp atomize_params(map) when is_map(map) do
    Enum.map(map, fn
      {k, v} when is_atom(k) -> {k, v}
      {k, v} when is_binary(k) -> {k, v}
    end)
  end
  defp atomize_params(_), do: []
end

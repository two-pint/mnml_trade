defmodule StockAnalysis.Integrations.Massive do
  @moduledoc """
  Massive.com (formerly Polygon.io, rebranded Oct 2025) API integration for
  quotes, daily OHLCV, and symbol search.

  API key is configured via application env or `MASSIVE_API_KEY` (never hard-coded).
  Free tier: 5 requests/minute.

  Base URL: `https://api.massive.com` (same Polygon.io API, new domain).
  Existing Polygon.io API keys are valid.
  """
  require Logger

  @default_base_url "https://api.massive.com"

  defp base_url do
    Application.get_env(:stock_analysis, :massive_base_url, @default_base_url)
  end

  defp api_key do
    Application.get_env(:stock_analysis, :massive_api_key) ||
      System.get_env("MASSIVE_API_KEY")
  end

  @doc """
  Fetches a fresh snapshot for a ticker (last trade, last quote, or latest minute bar).

  Calls `GET /v2/snapshot/locale/us/markets/stocks/tickers/{ticker}`. Uses last trade
  price or latest minute bar close for "price"; prevDay for previous_close and change.
  Returns the same shape as get_quote/1 for use in overview. Falls back to get_quote/1
  when snapshot is unavailable (e.g. 404 or plan doesn't include snapshot).
  """
  def get_snapshot(ticker) when is_binary(ticker) do
    symbol = String.upcase(String.trim(ticker))
    path = "/v2/snapshot/locale/us/markets/stocks/tickers/#{URI.encode(symbol)}"

    case get(path, []) do
      {:ok, %{"ticker" => t} = _body} when is_map(t) ->
        {:ok, normalize_snapshot(symbol, t)}

      {:ok, _} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_snapshot(symbol, t) do
    prev = t["prevDay"] || %{}
    day = t["day"] || %{}
    last_trade = t["lastTrade"] || %{}
    last_quote = t["lastQuote"] || %{}
    min_bar = t["min"] || %{}

    prev_close = num_or_nil(prev["c"])
    price =
      num_or_nil(last_trade["p"]) ||
        (if last_quote["p"] && last_quote["P"], do: (last_quote["p"] + last_quote["P"]) / 2, else: nil) ||
        num_or_nil(min_bar["c"]) ||
        num_or_nil(day["c"]) ||
        prev_close

    change = num_or_nil(t["todaysChange"]) || (if price && prev_close, do: price - prev_close, else: nil)
    change_pct = num_or_nil(t["todaysChangePerc"])
    change_percent =
      if change_pct != nil do
        "#{Float.round(change_pct, 4)}%"
      else
        if change && prev_close && prev_close != 0, do: "#{Float.round(change / prev_close * 100, 4)}%", else: nil
      end

    latest_date =
      case day["t"] || prev["t"] do
        ts when is_integer(ts) and ts > 0 ->
          ms = if ts > 1_000_000_000_000, do: div(ts, 1_000_000), else: ts
          DateTime.from_unix!(ms, :millisecond) |> DateTime.to_date() |> Date.to_iso8601()

        _ ->
          nil
      end

    %{
      symbol: symbol,
      open: num_or_nil(day["o"]) || num_or_nil(prev["o"]),
      high: num_or_nil(day["h"]) || num_or_nil(prev["h"]),
      low: num_or_nil(day["l"]) || num_or_nil(prev["l"]),
      price: price,
      volume: trunc_or_nil(day["v"]) || trunc_or_nil(prev["v"]),
      latest_trading_day: latest_date,
      previous_close: prev_close,
      change: change,
      change_percent: change_percent
    }
  end

  @doc """
  Fetches the current quote for a ticker.

  Calls `/v2/aggs/ticker/{ticker}/range/1/day/{from}/{to}` for the last 5 calendar
  days (to capture the most recent trading day). The latest bar is the "quote";
  the previous bar provides `previous_close`.

  Returns `{:ok, %{symbol, price, open, high, low, volume, change, change_percent,
  previous_close, latest_trading_day}}` or `{:error, reason}`.
  """
  def get_quote(ticker) when is_binary(ticker) do
    symbol = String.upcase(String.trim(ticker))
    to = Date.utc_today()
    from = Date.add(to, -5)
    path = "/v2/aggs/ticker/#{URI.encode(symbol)}/range/1/day/#{from}/#{to}"

    case get(path, []) do
      {:ok, %{"results" => [_ | _] = results}} ->
        sorted = Enum.sort_by(results, & &1["t"], :desc)
        [latest | rest] = sorted
        prev = List.first(rest)
        {:ok, normalize_quote(symbol, latest, prev)}

      {:ok, %{"results" => _}} ->
        {:error, :not_found}

      {:ok, _} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches intraday (minute/hour) OHLCV bars for a ticker.

  Uses the same aggregates endpoint with multiplier/timespan for minute or hour bars.
  `from`/`to` are passed as Unix milliseconds so the range is within-day or multi-day.

  Options:
    * `:interval` — `:minute` (1-min bars), `:"5minute"` (5-min), or `:hour` (default: `:minute`)
    * `:days` — number of calendar days to fetch back from now (default: 1). Max effective
      bars per request is 5000 (API limit).

  Returns `{:ok, [%{datetime, open, high, low, close, volume}]}` sorted desc by datetime,
  or `{:error, reason}`.
  """
  def get_intraday(ticker, opts \\ []) when is_binary(ticker) do
    symbol = String.upcase(String.trim(ticker))
    interval = Keyword.get(opts, :interval, :minute)
    days = Keyword.get(opts, :days, 1)

    {multiplier, timespan} = interval_to_multiplier_timespan(interval)
    to_ts = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    from_ts = to_ts - (days * 24 * 60 * 60 * 1000)

    path = "/v2/aggs/ticker/#{URI.encode(symbol)}/range/#{multiplier}/#{timespan}/#{from_ts}/#{to_ts}"

    case get(path, [limit: 5000, sort: "desc"]) do
      {:ok, %{"results" => results}} when is_list(results) ->
        bars =
          results
          |> Enum.map(&normalize_intraday_bar/1)
          |> Enum.sort_by(& &1.datetime, :desc)

        {:ok, bars}

      {:ok, %{"results" => _}} ->
        {:ok, []}

      {:ok, body} when is_map(body) ->
        # 200 but no "results" key (e.g. API error payload or plan limit); return empty rather than not_found
        Logger.debug("Massive.get_intraday: 200 with no results key for #{symbol}, keys: #{inspect(Map.keys(body))}")
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp interval_to_multiplier_timespan(:minute), do: {1, "minute"}
  defp interval_to_multiplier_timespan(:"5minute"), do: {5, "minute"}
  defp interval_to_multiplier_timespan(:hour), do: {1, "hour"}
  defp interval_to_multiplier_timespan("1min"), do: {1, "minute"}
  defp interval_to_multiplier_timespan("5min"), do: {5, "minute"}
  defp interval_to_multiplier_timespan("1h"), do: {1, "hour"}
  defp interval_to_multiplier_timespan(_), do: {1, "minute"}

  @doc """
  Fetches daily OHLCV series for a ticker (last 300 calendar days, covering SMA-200).

  Returns `{:ok, [%{date, open, high, low, close, volume}]}` sorted desc by date,
  or `{:error, reason}`.
  """
  def get_daily(ticker) when is_binary(ticker) do
    symbol = String.upcase(String.trim(ticker))
    to = Date.utc_today()
    from = Date.add(to, -300)
    path = "/v2/aggs/ticker/#{URI.encode(symbol)}/range/1/day/#{from}/#{to}"

    case get(path, [limit: 300]) do
      {:ok, %{"results" => results}} when is_list(results) ->
        bars =
          results
          |> Enum.map(&normalize_bar/1)
          |> Enum.sort_by(& &1.date, :desc)

        {:ok, bars}

      {:ok, _} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Searches for stocks by query string.

  Returns `{:ok, [%{ticker, name, type, region}]}` or `{:error, reason}`.
  """
  def symbol_search(query) when is_binary(query) do
    case get("/v3/reference/tickers", [search: query, active: "true", market: "stocks"]) do
      {:ok, %{"results" => results}} when is_list(results) ->
        {:ok, Enum.map(results, &normalize_ticker_result/1)}

      {:ok, _} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Private: HTTP helper

  defp get(path, params) do
    key = api_key()

    if is_nil(key) or key == "" do
      Logger.warning("Massive: API key not configured")
      {:error, :api_key_missing}
    else
      url = base_url() <> path

      all_params =
        [apiKey: key]
        |> Keyword.merge(params)
        |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)

      opts = [
        params: all_params,
        receive_timeout: 15_000,
        retry: Application.get_env(:stock_analysis, :req_retry, :transient)
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

  ## Private: normalization

  defp normalize_quote(symbol, latest, prev) do
    close = num_or_nil(latest["c"])
    prev_close = if prev, do: num_or_nil(prev["c"]), else: nil
    change = if close && prev_close, do: close - prev_close, else: nil

    change_percent =
      if change && prev_close && prev_close != 0 do
        "#{Float.round(change / prev_close * 100, 4)}%"
      else
        nil
      end

    date =
      case latest["t"] do
        t when is_integer(t) ->
          DateTime.from_unix!(t, :millisecond) |> DateTime.to_date() |> Date.to_iso8601()

        _ ->
          nil
      end

    %{
      symbol: symbol,
      open: num_or_nil(latest["o"]),
      high: num_or_nil(latest["h"]),
      low: num_or_nil(latest["l"]),
      price: close,
      volume: trunc_or_nil(latest["v"]),
      latest_trading_day: date,
      previous_close: prev_close,
      change: change,
      change_percent: change_percent
    }
  end

  defp normalize_bar(bar) do
    date =
      case bar["t"] do
        t when is_integer(t) ->
          DateTime.from_unix!(t, :millisecond) |> DateTime.to_date() |> Date.to_iso8601()

        _ ->
          nil
      end

    %{
      date: date,
      open: num_or_nil(bar["o"]),
      high: num_or_nil(bar["h"]),
      low: num_or_nil(bar["l"]),
      close: num_or_nil(bar["c"]),
      volume: trunc_or_nil(bar["v"])
    }
  end

  defp normalize_intraday_bar(bar) do
    datetime =
      case bar["t"] do
        t when is_integer(t) ->
          DateTime.from_unix!(t, :millisecond) |> DateTime.to_iso8601()

        _ ->
          nil
      end

    %{
      datetime: datetime,
      open: num_or_nil(bar["o"]),
      high: num_or_nil(bar["h"]),
      low: num_or_nil(bar["l"]),
      close: num_or_nil(bar["c"]),
      volume: trunc_or_nil(bar["v"])
    }
  end

  defp normalize_ticker_result(raw) do
    %{
      ticker: raw["ticker"],
      name: raw["name"],
      type: raw["type"],
      region: raw["market"] || raw["primary_exchange"]
    }
  end

  defp num_or_nil(nil), do: nil
  defp num_or_nil(n) when is_number(n), do: n * 1.0

  defp num_or_nil(s) when is_binary(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp num_or_nil(_), do: nil

  defp trunc_or_nil(nil), do: nil
  defp trunc_or_nil(n) when is_integer(n), do: n
  defp trunc_or_nil(n) when is_float(n), do: trunc(n)

  defp trunc_or_nil(s) when is_binary(s) do
    case Integer.parse(s) do
      {i, _} -> i
      :error -> nil
    end
  end

  defp trunc_or_nil(_), do: nil
end

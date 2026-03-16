defmodule StockAnalysis.Stocks do
  @moduledoc """
  Context for stock search and overview.

  Orchestrates cache checks and Massive.com calls. Overview data is cached per TTL (price: 15s).
  """
  alias StockAnalysis.Cache
  alias StockAnalysis.Integrations.Massive

  @doc """
  Searches for stocks by ticker or name.

  Returns `{:ok, [%{ticker: _, name: _, type: _, region: _}, ...]}` or `{:error, reason}`.
  """
  def search(query) when is_binary(query) do
    query = String.trim(query)
    if query == "" do
      {:ok, []}
    else
      Massive.symbol_search(query)
    end
  end

  @doc """
  Fetches stock overview (quote) for a ticker.

  Uses cache first (TTL 15s for price); on miss fetches from Massive.com, caches, and returns.
  Returns `{:ok, overview}` map with price, change, volume, high, low, etc., or `{:error, :not_found}`.
  """
  def get_overview(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    cache_key = Cache.key("stocks", ticker, "price")
    ttl = Cache.default_ttl(:price)

    case Cache.get(cache_key) do
      nil ->
        fetch_and_cache_overview(ticker, cache_key, ttl)

      cached ->
        {:ok, cached}
    end
  end

  defp fetch_and_cache_overview(ticker, cache_key, ttl) do
    case Massive.get_snapshot(ticker) do
      {:ok, snapshot} ->
        overview = quote_to_overview(ticker, snapshot)
        Cache.put(cache_key, overview, ttl)
        {:ok, overview}

      {:error, :rate_limit} ->
        {:error, :rate_limit}

      _ ->
        # Snapshot often unavailable on free tier; use latest minute bar + daily for real-time-ish price
        overview_from_intraday_fallback(ticker, cache_key, ttl)
    end
  end

  defp overview_from_intraday_fallback(ticker, cache_key, ttl) do
    with {:ok, quote} <- Massive.get_quote(ticker),
         {:ok, intraday_bars} <- Massive.get_intraday(ticker, interval: :minute, days: 1),
         [latest | _] <- intraday_bars,
         price when is_number(price) <- latest.close do
      prev_close = quote.previous_close
      change = if prev_close, do: price - prev_close, else: nil
      change_percent =
        if change && prev_close && prev_close != 0 do
          "#{Float.round(change / prev_close * 100, 4)}%"
        else
          quote.change_percent
        end

      quote_with_live_price = %{
        symbol: quote.symbol,
        price: price,
        open: quote.open,
        high: quote.high,
        low: quote.low,
        volume: quote.volume,
        previous_close: prev_close,
        change: change,
        change_percent: change_percent,
        latest_trading_day: quote.latest_trading_day
      }

      overview = quote_to_overview(ticker, quote_with_live_price)
      Cache.put(cache_key, overview, ttl)
      {:ok, overview}
    else
      _ ->
        # No intraday or quote failed; use daily quote only
        case Massive.get_quote(ticker) do
          {:ok, quote} ->
            overview = quote_to_overview(ticker, quote)
            Cache.put(cache_key, overview, ttl)
            {:ok, overview}

          {:error, :rate_limit} ->
            {:error, :rate_limit}

          _ ->
            {:error, :not_found}
        end
    end
  end

  @trending_tickers ~w(AAPL MSFT GOOGL AMZN NVDA)

  @doc """
  Returns a list of trending/popular stocks with price and change.

  Uses cache (1h TTL). For MVP returns a static seed list; each ticker's
  overview is fetched (via cache) and normalized to trending shape.
  """
  def get_trending do
    cache_key = "stocks:trending:list"
    ttl = Cache.default_ttl(:technical)

    case Cache.get(cache_key) do
      nil ->
        list = fetch_trending_overviews()
        Cache.put(cache_key, list, ttl)
        {:ok, list}

      cached ->
        {:ok, cached}
    end
  end

  defp fetch_trending_overviews do
    @trending_tickers
    |> Enum.reduce({[], false}, fn ticker, {acc, rate_limited} ->
      if rate_limited do
        {acc, true}
      else
        case get_overview(ticker) do
          {:ok, overview} ->
            Process.sleep(1_500)
            {[overview_to_trending(overview) | acc], false}

          {:error, :rate_limit} ->
            {acc, true}

          _ ->
            {acc, false}
        end
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp overview_to_trending(overview) do
    %{
      ticker: overview.ticker,
      name: overview.ticker,
      price: overview.price,
      change: overview.change,
      change_percent: overview.change_percent
    }
  end

  @doc """
  Fetches intraday OHLCV bars for a ticker (minute or hour bars for charts).

  Options: `:interval` — `:minute`, `:"5minute"`, or `:hour` (default `:minute`);
  `:days` — calendar days back (default 1). Uses cache (1 min TTL).

  Returns `{:ok, [%{datetime: _, open: _, high: _, low: _, close: _, volume: _}, ...]}`
  or `{:error, :not_found}`.
  """
  def get_intraday(ticker, opts \\ []) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    interval = Keyword.get(opts, :interval, :minute)
    days = Keyword.get(opts, :days, 1)
    cache_key = Cache.key("stocks", ticker, "intraday:#{interval}:#{days}")
    ttl = Cache.default_ttl(:intraday)

    case Cache.get(cache_key) do
      nil ->
        case Massive.get_intraday(ticker, interval: interval, days: days) do
          {:ok, series} ->
            Cache.put(cache_key, series, ttl)
            {:ok, series}

          {:error, :rate_limit} ->
            {:error, :rate_limit}

          {:error, :api_key_missing} ->
            {:error, :api_key_missing}

          {:error, _} ->
            {:error, :not_found}
        end

      cached ->
        {:ok, cached}
    end
  end

  @doc """
  Fetches daily OHLCV series for a ticker (for charts).

  Uses cache (1h TTL). Returns `{:ok, [%{date: _, open: _, high: _, low: _, close: _, volume: _}, ...]}`
  or `{:error, :not_found}`.
  """
  def get_daily(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    cache_key = Cache.key("stocks", ticker, "daily")
    ttl = Cache.default_ttl(:technical)

    case Cache.get(cache_key) do
      nil ->
        case Massive.get_daily(ticker) do
          {:ok, series} ->
            Cache.put(cache_key, series, ttl)
            {:ok, series}

          {:error, :rate_limit} ->
            {:error, :rate_limit}

          {:error, _} ->
            {:error, :not_found}
        end

      cached ->
        {:ok, cached}
    end
  end

  defp quote_to_overview(ticker, quote) do
    %{
      ticker: ticker,
      symbol: quote.symbol,
      price: quote.price,
      change: quote.change,
      change_percent: quote.change_percent,
      volume: quote.volume,
      open: quote.open,
      high: quote.high,
      low: quote.low,
      previous_close: quote.previous_close,
      latest_trading_day: quote.latest_trading_day
    }
  end
end

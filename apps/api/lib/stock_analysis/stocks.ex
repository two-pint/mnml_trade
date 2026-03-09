defmodule StockAnalysis.Stocks do
  @moduledoc """
  Context for stock search and overview.

  Orchestrates cache checks and Alpha Vantage calls. Overview data is cached per TTL (price: 15s).

  Overview is partial for M2: price, change, volume, OHLC. Market cap and 52-week range
  will be added when the Alpha Vantage OVERVIEW endpoint is integrated.
  """
  alias StockAnalysis.Cache
  alias StockAnalysis.Integrations.AlphaVantage

  @doc """
  Searches for stocks by ticker or name.

  Returns `{:ok, [%{ticker: _, name: _, type: _, region: _}, ...]}` or `{:error, reason}`.
  """
  def search(query) when is_binary(query) do
    query = String.trim(query)
    if query == "" do
      {:ok, []}
    else
      AlphaVantage.symbol_search(query)
    end
  end

  @doc """
  Fetches stock overview (quote) for a ticker.

  Uses cache first (TTL 15s for price); on miss fetches from Alpha Vantage, caches, and returns.
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
    case AlphaVantage.get_quote(ticker) do
      {:ok, quote} ->
        overview = quote_to_overview(ticker, quote)
        Cache.put(cache_key, overview, ttl)
        {:ok, overview}

      {:error, :rate_limit} ->
        {:error, :rate_limit}

      {:error, _reason} ->
        {:error, :not_found}
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
        case AlphaVantage.get_daily(ticker) do
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

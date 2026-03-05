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

      {:error, _reason} ->
        {:error, :not_found}
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

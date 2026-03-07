defmodule StockAnalysis.InstitutionalActivity do
  @moduledoc """
  Context for institutional data: options flow, dark pool, congressional trades,
  insider trades, institutional holdings (13F), market tide, and smart money score.

  Delegates to Unusual Whales integration, caches results per ticker with appropriate
  TTLs, and includes `data_as_of` (ISO timestamp). When rate limit is hit, returns
  cached data with `stale: true` instead of failing.
  """
  alias StockAnalysis.Cache
  alias StockAnalysis.Integrations.UnusualWhales

  @doc """
  Fetches basic institutional data for a ticker: options flow + dark pool.

  Uses cache first (1h TTL). On miss, fetches both from Unusual Whales, builds
  payload with `data_as_of` (ISO8601), caches and returns.

  When the integration returns `:rate_limit`, returns any cached data for the ticker
  with `stale: true`; if no cache, returns `{:error, :rate_limit}`.
  """
  def get_basic(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    cache_key = Cache.key("institutional", ticker, "basic")
    ttl = Cache.default_ttl(:institutional)

    case Cache.get(cache_key) do
      nil ->
        fetch_and_cache_basic(ticker, cache_key, ttl)

      cached ->
        {:ok, Map.put(cached, :stale, false)}
    end
  end

  @doc """
  Fetches full institutional data: options flow + dark pool + congressional +
  insider + holdings + market tide + smart money score.

  Uses individual caches per data type with varying TTLs.
  Returns `{:ok, payload}` or `{:error, :not_found}`.
  """
  def get_full(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))

    basic = safe_fetch(fn -> get_basic(ticker) end)
    congressional = cached_fetch("institutional", ticker, "congressional", :congressional, fn ->
      UnusualWhales.get_congressional(ticker)
    end)
    insider = cached_fetch("institutional", ticker, "insider", :insider, fn ->
      UnusualWhales.get_insider_trades(ticker)
    end)
    holdings = cached_fetch("institutional", ticker, "holdings", :holdings, fn ->
      UnusualWhales.get_institutional_holdings(ticker)
    end)
    market_tide = cached_fetch("institutional", "_market", "tide", :market_tide, fn ->
      UnusualWhales.get_market_tide()
    end)

    options_flow = if basic, do: basic[:options_flow] || [], else: []
    dark_pool = if basic, do: basic[:dark_pool] || %{}, else: %{}

    smart_money = compute_smart_money_score(options_flow, dark_pool, congressional, insider)

    payload = %{
      ticker: ticker,
      options_flow: options_flow,
      dark_pool: dark_pool,
      congressional: congressional,
      insider: insider,
      holdings: holdings,
      market_tide: market_tide,
      smart_money_score: smart_money.score,
      smart_money_label: smart_money.label,
      data_as_of: DateTime.utc_now() |> DateTime.to_iso8601(),
      stale: if(basic, do: basic[:stale] || false, else: false)
    }

    {:ok, payload}
  end

  @doc """
  Fetches congressional trades for a ticker (cached 24h).
  """
  def get_congressional(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    data = cached_fetch("institutional", ticker, "congressional", :congressional, fn ->
      UnusualWhales.get_congressional(ticker)
    end)
    {:ok, %{ticker: ticker, trades: data, data_as_of: DateTime.utc_now() |> DateTime.to_iso8601()}}
  end

  @doc """
  Fetches insider trades for a ticker (cached 24h).
  """
  def get_insider_trades(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    data = cached_fetch("institutional", ticker, "insider", :insider, fn ->
      UnusualWhales.get_insider_trades(ticker)
    end)
    {:ok, %{ticker: ticker, trades: data, data_as_of: DateTime.utc_now() |> DateTime.to_iso8601()}}
  end

  @doc """
  Fetches institutional holdings (13F) for a ticker (cached 7d).
  """
  def get_holdings(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    data = cached_fetch("institutional", ticker, "holdings", :holdings, fn ->
      UnusualWhales.get_institutional_holdings(ticker)
    end)
    {:ok, %{ticker: ticker, holdings: data, data_as_of: DateTime.utc_now() |> DateTime.to_iso8601()}}
  end

  @doc """
  Fetches market tide (market-wide sentiment, cached 1h).
  """
  def get_market_tide do
    data = cached_fetch("institutional", "_market", "tide", :market_tide, fn ->
      UnusualWhales.get_market_tide()
    end)
    {:ok, data}
  end

  @doc """
  Computes smart money score for a ticker using existing cached data.
  Returns `{:ok, %{ticker: _, score: _, label: _}}`.
  """
  def get_smart_money_score(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    basic = safe_fetch(fn -> get_basic(ticker) end)
    options_flow = if basic, do: basic[:options_flow] || [], else: []
    dark_pool = if basic, do: basic[:dark_pool] || %{}, else: %{}
    congressional = cached_fetch("institutional", ticker, "congressional", :congressional, fn ->
      UnusualWhales.get_congressional(ticker)
    end)
    insider = cached_fetch("institutional", ticker, "insider", :insider, fn ->
      UnusualWhales.get_insider_trades(ticker)
    end)

    result = compute_smart_money_score(options_flow, dark_pool, congressional, insider)
    {:ok, Map.put(result, :ticker, ticker)}
  end

  @doc """
  Computes a smart money score (0-100) from institutional data signals.

  Factors:
  - Options flow sentiment (bullish/bearish ratio)
  - Dark pool net buy/sell direction
  - Congressional buy/sell ratio
  - Insider buy/sell ratio
  """
  def compute_smart_money_score(options_flow, dark_pool, congressional, insider) do
    flow_score = options_flow_score(options_flow)
    dp_score = dark_pool_score(dark_pool)
    cong_score = congressional_score(congressional)
    insider_score = insider_score(insider)

    components = [flow_score, dp_score, cong_score, insider_score] |> Enum.reject(&is_nil/1)

    score = if Enum.empty?(components) do
      50
    else
      round(Enum.sum(components) / length(components))
    end

    score = max(0, min(100, score))
    label = cond do
      score >= 70 -> "Strong Institutional Buy"
      score >= 55 -> "Institutional Buy"
      score >= 45 -> "Neutral"
      score >= 30 -> "Institutional Sell"
      true -> "Strong Institutional Sell"
    end

    %{score: score, label: label}
  end

  ## Private: basic fetch

  defp fetch_and_cache_basic(ticker, cache_key, ttl) do
    with {:ok, flow} <- UnusualWhales.get_options_flow(ticker),
         {:ok, dark_pool} <- UnusualWhales.get_dark_pool(ticker) do
      data_as_of = DateTime.utc_now() |> DateTime.to_iso8601()
      payload = %{
        ticker: ticker,
        options_flow: flow,
        dark_pool: dark_pool,
        data_as_of: data_as_of,
        stale: false
      }

      Cache.put(cache_key, payload, ttl)
      stale_key = cache_key <> "_stale"
      Cache.put(stale_key, payload, 86_400)
      {:ok, payload}
    else
      {:error, :rate_limit} ->
        stale_key = cache_key <> "_stale"
        case Cache.get(stale_key) do
          nil -> {:error, :rate_limit}
          cached -> {:ok, Map.put(cached, :stale, true)}
        end

      _ ->
        {:error, :not_found}
    end
  end

  ## Private: cached fetch helper

  defp cached_fetch(scope, ticker, data_type, ttl_key, fetch_fn) do
    cache_key = Cache.key(scope, ticker, data_type)
    ttl = Cache.default_ttl(ttl_key)

    case Cache.get(cache_key) do
      nil ->
        case fetch_fn.() do
          {:ok, data} ->
            Cache.put(cache_key, data, ttl)
            data

          {:error, _} ->
            nil
        end

      cached ->
        cached
    end
  end

  defp safe_fetch(fun) do
    case fun.() do
      {:ok, data} -> data
      {:error, _} -> nil
    end
  end

  ## Private: smart money sub-scores

  defp options_flow_score([]), do: 50

  defp options_flow_score(trades) when is_list(trades) do
    sentiments = Enum.map(trades, fn t ->
      s = (t[:sentiment] || "") |> String.downcase()
      cond do
        s in ["bullish", "positive", "buy"] -> 1
        s in ["bearish", "negative", "sell"] -> -1
        true -> 0
      end
    end)

    total = length(sentiments)
    if total == 0 do
      50
    else
      bull_ratio = Enum.count(sentiments, &(&1 == 1)) / total
      round(bull_ratio * 100)
    end
  end

  defp options_flow_score(_), do: 50

  defp dark_pool_score(%{net_buy_sell: net}) when is_number(net) do
    cond do
      net > 0 -> 65
      net < 0 -> 35
      true -> 50
    end
  end

  defp dark_pool_score(_), do: nil

  defp congressional_score(nil), do: nil
  defp congressional_score([]), do: 50

  defp congressional_score(trades) when is_list(trades) do
    buys = Enum.count(trades, fn t ->
      type = String.downcase(t[:transaction_type] || "")
      type in ["purchase", "buy"]
    end)
    sells = Enum.count(trades, fn t ->
      type = String.downcase(t[:transaction_type] || "")
      type in ["sale", "sell", "sale (full)", "sale (partial)"]
    end)

    total = buys + sells
    if total == 0, do: 50, else: round(buys / total * 100)
  end

  defp insider_score(nil), do: nil
  defp insider_score([]), do: 50

  defp insider_score(trades) when is_list(trades) do
    buys = Enum.count(trades, fn t ->
      type = String.downcase(t[:transaction_type] || "")
      type in ["purchase", "buy", "p - purchase"]
    end)
    sells = Enum.count(trades, fn t ->
      type = String.downcase(t[:transaction_type] || "")
      type in ["sale", "sell", "s - sale", "s - sale+oe"]
    end)

    total = buys + sells
    if total == 0, do: 50, else: round(buys / total * 100)
  end
end

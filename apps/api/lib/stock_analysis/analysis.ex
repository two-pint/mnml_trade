defmodule StockAnalysis.Analysis do
  @moduledoc """
  Context for technical analysis: indicators and aggregated score.

  Fetches RSI, MACD, SMAs (20/50/200), Bollinger Bands, ATR, ADX, Stochastic from
  Alpha Vantage, caches the combined result per ticker (1h TTL), and computes
  a 0–100 technical score with trend direction and support/resistance estimate.
  """
  alias StockAnalysis.Cache
  alias StockAnalysis.Integrations.AlphaVantage

  @doc """
  Fetches full technical analysis for a ticker.

  Uses cache first (1h TTL); on miss fetches quote and all indicators from
  Alpha Vantage, computes score, caches and returns.

  Returns `{:ok, technical}` map with `:indicators`, `:score`, `:signal`,
  `:trend_direction`, `:support_resistance`, or `{:error, :not_found}`.
  """
  def get_technical(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    cache_key = Cache.key("analysis", ticker, "technical")
    ttl = Cache.default_ttl(:technical)

    case Cache.get(cache_key) do
      nil ->
        fetch_and_cache_technical(ticker, cache_key, ttl)

      cached ->
        {:ok, cached}
    end
  end

  @doc """
  Computes an aggregated technical score (0–100) and signal from indicator values.

  Rules (simplified):
  - RSI < 30 bullish, > 70 bearish
  - Price above SMA-200 bullish, below bearish
  - MACD histogram > 0 bullish, < 0 bearish
  - Price below lower Bollinger = oversold (bullish), above upper = overbought (bearish)
  - ADX > 25 strengthens trend signal
  - Stochastic < 20 bullish, > 80 bearish

  Returns `%{score: 0..100, signal: :bullish | :bearish | :neutral}`.
  """
  def compute_technical_score(indicators, current_price) when is_number(current_price) do
    score = compute_score(indicators, current_price)
    signal = score_to_signal(score)
    %{score: score, signal: signal}
  end

  def compute_technical_score(_indicators, _current_price), do: %{score: 50, signal: :neutral}

  ## Private: fetch and build technical map

  defp fetch_and_cache_technical(ticker, cache_key, ttl) do
    with {:ok, quote} <- AlphaVantage.get_quote(ticker),
         {:ok, indicators} <- fetch_all_indicators(ticker) do
      price = quote.price || 0
      score_result = compute_technical_score(indicators, price)
      support_resistance = estimate_support_resistance(indicators, price)
      trend_direction = score_to_signal(score_result.score)

      technical = %{
        ticker: ticker,
        indicators: indicators,
        score: score_result.score,
        signal: score_result.signal,
        trend_direction: trend_direction,
        support_resistance: support_resistance
      }

      Cache.put(cache_key, technical, ttl)
      {:ok, technical}
    else
      _ -> {:error, :not_found}
    end
  end

  defp fetch_all_indicators(ticker) do
    results = %{
      rsi: fetch_indicator(ticker, :rsi, %{time_period: 14}),
      macd: fetch_indicator(ticker, :macd, %{fastperiod: 12, slowperiod: 26, signalperiod: 9}),
      sma_20: fetch_indicator(ticker, :sma, %{time_period: 20}),
      sma_50: fetch_indicator(ticker, :sma, %{time_period: 50}),
      sma_200: fetch_indicator(ticker, :sma, %{time_period: 200}),
      bbands: fetch_indicator(ticker, :bbands, %{time_period: 20}),
      atr: fetch_indicator(ticker, :atr, %{time_period: 14}),
      adx: fetch_indicator(ticker, :adx, %{time_period: 14}),
      stoch: fetch_indicator(ticker, :stoch, %{})
    }

    # Build indicators from successes; nil for failures. Score uses whatever is available.
    indicators =
      results
      |> Enum.map(fn
        {key, {:ok, series}} -> {key, latest_from_series(series)}
        {key, {:error, _}} -> {key, nil}
      end)
      |> Map.new()

    # Require at least quote (for price) and one indicator so we don't cache empty
    if Enum.any?(indicators, fn {_k, v} -> v != nil end) do
      {:ok, indicators}
    else
      {:error, :not_found}
    end
  end

  defp fetch_indicator(ticker, name, params) do
    AlphaVantage.get_technical_indicator(ticker, name, params)
  end

  defp latest_from_series([]), do: nil
  defp latest_from_series([%{date: date, value: value} | _]), do: %{date: date, value: value}

  ## Private: scoring

  defp compute_score(indicators, price) do
    components =
      [
        rsi_component(indicators),
        sma_component(indicators, price),
        macd_component(indicators),
        bbands_component(indicators, price),
        adx_strength(indicators),
        stoch_component(indicators)
      ]
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(components) do
      50
    else
      sum = Enum.sum(components)
      count = length(components)
      raw = 50 + sum / max(count, 1)
      round(max(0, min(100, raw)))
    end
  end

  defp rsi_component(%{rsi: %{value: v}}) when is_number(v) do
    cond do
      v < 30 -> 15
      v > 70 -> -15
      true -> 0
    end
  end
  defp rsi_component(_), do: 0

  defp sma_component(%{sma_20: s20, sma_50: s50, sma_200: s200}, price) when is_number(price) do
    v20 = num_value(s20)
    v50 = num_value(s50)
    v200 = num_value(s200)
    component_200 = if v200 && price > v200, do: 8, else: if(v200 && price < v200, do: -8, else: 0)
    component_50 = if v50 && price > v50, do: 4, else: if(v50 && price < v50, do: -4, else: 0)
    component_20 = if v20 && price > v20, do: 2, else: if(v20 && price < v20, do: -2, else: 0)
    component_200 + component_50 + component_20
  end
  defp sma_component(_, _), do: 0

  defp num_value(nil), do: nil
  defp num_value(%{value: v}) when is_number(v), do: v
  defp num_value(%{value: [v | _]}) when is_number(v), do: v
  defp num_value(_), do: nil

  defp macd_component(%{macd: %{value: v}}) when is_number(v) do
    if v > 0, do: 5, else: if(v < 0, do: -5, else: 0)
  end
  defp macd_component(%{macd: %{value: [_macd, _signal, hist | _]}}) when is_number(hist) do
    if hist > 0, do: 5, else: if(hist < 0, do: -5, else: 0)
  end
  defp macd_component(_), do: 0

  defp bbands_component(%{bbands: %{value: v}}, price) when is_list(v) and is_number(price) do
    nums = Enum.filter(v, &is_number/1)
    if length(nums) >= 2 do
      lower = Enum.min(nums)
      upper = Enum.max(nums)
      cond do
        price <= lower -> 5
        price >= upper -> -5
        true -> 0
      end
    else
      0
    end
  end
  defp bbands_component(_, _), do: 0

  defp adx_strength(%{adx: %{value: v}}) when is_number(v) and v > 25 do
    # Strong trend: don't change score, but could amplify others; keep simple
    0
  end
  defp adx_strength(_), do: 0

  defp stoch_component(%{stoch: %{value: v}}) when is_number(v) do
    cond do
      v < 20 -> 5
      v > 80 -> -5
      true -> 0
    end
  end
  defp stoch_component(%{stoch: %{value: [k, _d]}}) when is_number(k) do
    cond do
      k < 20 -> 5
      k > 80 -> -5
      true -> 0
    end
  end
  defp stoch_component(_), do: 0

  defp score_to_signal(score) when score >= 55, do: :bullish
  defp score_to_signal(score) when score <= 45, do: :bearish
  defp score_to_signal(_), do: :neutral

  defp estimate_support_resistance(indicators, price) do
    # Simple estimate: use recent SMA-20 and SMA-200 as proxy, or fixed % around price
    sma_20 = num_value(Map.get(indicators, :sma_20))
    sma_200 = num_value(Map.get(indicators, :sma_200))

    support =
      cond do
        is_number(sma_200) and price > sma_200 -> sma_200
        is_number(sma_20) -> sma_20
        true -> price * 0.95
      end

    resistance =
      cond do
        is_number(sma_20) and price < sma_20 -> sma_20
        true -> price * 1.05
      end

    %{support: support, resistance: resistance}
  end
end

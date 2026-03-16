defmodule StockAnalysis.Analysis do
  @moduledoc """
  Context for technical and fundamental analysis.

  Technical: fetches daily OHLCV from Massive.com, computes RSI, MACD, SMAs
  (20/50/200), Bollinger Bands, and Stochastic locally via TechnicalIndicators,
  caches (1h TTL), computes 0-100 score.

  Fundamental: fetches profile, ratios, and financial statements from FMP,
  caches (24h TTL), computes 0-100 score with value assessment.
  """
  alias StockAnalysis.Cache
  alias StockAnalysis.Integrations.Massive
  alias StockAnalysis.Integrations.FMP
  alias StockAnalysis.TechnicalIndicators

  @doc """
  Fetches full technical analysis for a ticker.

  Uses cache first (1h TTL); on miss fetches quote from Massive.com and
  computes all indicators locally from daily OHLCV data, caches and returns.

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
    with {:ok, quote} <- Massive.get_quote(ticker),
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
      {:error, :rate_limit} -> {:error, :rate_limit}
      _ -> {:error, :not_found}
    end
  end

  defp fetch_all_indicators(ticker) do
    case Massive.get_daily(ticker) do
      {:ok, daily_data} ->
        # Filter to bars with all required fields, keeping alignment across lists
        bars = Enum.filter(daily_data, fn b -> b.close && b.high && b.low end)
        closes = Enum.map(bars, & &1.close)
        highs = Enum.map(bars, & &1.high)
        lows = Enum.map(bars, & &1.low)
        latest_date = bars |> List.first() |> then(fn b -> if b, do: b.date, else: nil end)

        # Wrap a scalar value in the {date, value} shape expected by scoring functions
        wrap = fn val -> if val, do: %{date: latest_date, value: val}, else: nil end

        rsi_val = TechnicalIndicators.rsi(closes)
        macd_val = TechnicalIndicators.macd(closes)
        sma_20_val = TechnicalIndicators.sma(closes, 20)
        sma_50_val = TechnicalIndicators.sma(closes, 50)
        sma_200_val = TechnicalIndicators.sma(closes, 200)
        bbands_val = TechnicalIndicators.bbands(closes)
        stoch_val = TechnicalIndicators.stoch(highs, lows, closes)

        indicators = %{
          rsi: wrap.(rsi_val),
          macd:
            if(macd_val,
              do: %{date: latest_date, value: macd_val.histogram},
              else: nil
            ),
          sma_20: wrap.(sma_20_val),
          sma_50: wrap.(sma_50_val),
          sma_200: wrap.(sma_200_val),
          bbands:
            if(bbands_val,
              do: %{date: latest_date, value: [bbands_val.upper, bbands_val.middle, bbands_val.lower]},
              else: nil
            ),
          atr: nil,
          adx: nil,
          stoch:
            if(stoch_val,
              do: %{date: latest_date, value: [stoch_val.k, stoch_val.d]},
              else: nil
            )
        }

        if Enum.any?(indicators, fn {_k, v} -> v != nil end) do
          {:ok, indicators}
        else
          {:error, :not_found}
        end

      {:error, :rate_limit} ->
        {:error, :rate_limit}

      {:error, _} ->
        {:error, :not_found}
    end
  end


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

  # ---------------------------------------------------------------------------
  # Fundamental analysis
  # ---------------------------------------------------------------------------

  @doc """
  Fetches full fundamental analysis for a ticker.

  Uses cache (24h TTL); on miss fetches profile, ratios, and financial
  statements from FMP, computes a 0-100 score, and returns the combined result.

  Returns `{:ok, fundamental}` map with `:profile`, `:ratios`, `:income_statement`,
  `:balance_sheet`, `:cash_flow`, `:score`, `:assessment`, `:growth_rating`,
  `:health_rating`, or `{:error, :not_found}`.
  """
  def get_fundamental(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    cache_key = Cache.key("analysis", ticker, "fundamental")
    ttl = Cache.default_ttl(:fundamental)

    case Cache.get(cache_key) do
      nil ->
        fetch_and_cache_fundamental(ticker, cache_key, ttl)

      cached ->
        {:ok, cached}
    end
  end

  @doc """
  Computes a fundamental score (0-100) and value assessment from ratios and profile.

  Scoring dimensions:
  - Valuation: P/E, P/B, PEG
  - Profitability: ROE, net margin, operating margin
  - Financial health: current ratio, D/E, interest coverage

  Returns `%{score: 0..100, assessment: label, growth_rating: label, health_rating: label}`.
  """
  def compute_fundamental_score(ratios, _profile) when is_map(ratios) do
    valuation = valuation_score(ratios)
    profitability = profitability_score(ratios)
    health = health_score(ratios)

    raw = (valuation * 0.35 + profitability * 0.35 + health * 0.30)
    score = round(max(0, min(100, raw)))

    %{
      score: score,
      assessment: assessment_label(score),
      growth_rating: profitability_label(profitability),
      health_rating: health_label(health)
    }
  end

  def compute_fundamental_score(_, _), do: %{score: 50, assessment: "Fairly Valued", growth_rating: "Average", health_rating: "Average"}

  defp fetch_and_cache_fundamental(ticker, cache_key, ttl) do
    with {:ok, profile} <- FMP.get_profile(ticker),
         {:ok, ratios} <- FMP.get_ratios(ticker) do
      income = safe_fetch(fn -> FMP.get_income_statement(ticker, :quarterly) end)
      balance = safe_fetch(fn -> FMP.get_balance_sheet(ticker) end)
      cashflow = safe_fetch(fn -> FMP.get_cash_flow(ticker) end)

      score_result = compute_fundamental_score(ratios, profile)

      fundamental = %{
        ticker: ticker,
        profile: profile,
        ratios: ratios,
        income_statement: income,
        balance_sheet: balance,
        cash_flow: cashflow,
        score: score_result.score,
        assessment: score_result.assessment,
        growth_rating: score_result.growth_rating,
        health_rating: score_result.health_rating
      }

      Cache.put(cache_key, fundamental, ttl)
      {:ok, fundamental}
    else
      {:error, :rate_limit} -> {:error, :rate_limit}
      _ -> {:error, :not_found}
    end
  end

  defp safe_fetch(fun) do
    case fun.() do
      {:ok, data} -> data
      {:error, _} -> []
    end
  end

  ## Fundamental scoring helpers

  defp valuation_score(ratios) do
    pe = safe_num(ratios.pe_ratio)
    pb = safe_num(ratios.pb_ratio)
    peg = safe_num(ratios.peg_ratio)

    pe_score = cond do
      is_nil(pe) -> 50
      pe < 0 -> 20
      pe < 10 -> 90
      pe < 15 -> 75
      pe < 25 -> 55
      pe < 40 -> 35
      true -> 15
    end

    pb_score = cond do
      is_nil(pb) -> 50
      pb < 1 -> 85
      pb < 3 -> 65
      pb < 5 -> 45
      true -> 25
    end

    peg_score = cond do
      is_nil(peg) -> 50
      peg < 0 -> 20
      peg < 1 -> 85
      peg < 2 -> 60
      true -> 30
    end

    (pe_score * 0.4 + pb_score * 0.3 + peg_score * 0.3)
  end

  defp profitability_score(ratios) do
    roe = safe_num(ratios.roe)
    net_margin = safe_num(ratios.net_margin)
    op_margin = safe_num(ratios.operating_margin)

    roe_score = cond do
      is_nil(roe) -> 50
      roe > 0.25 -> 90
      roe > 0.15 -> 70
      roe > 0.08 -> 50
      roe > 0 -> 30
      true -> 15
    end

    margin_score = cond do
      is_nil(net_margin) -> 50
      net_margin > 0.20 -> 85
      net_margin > 0.10 -> 65
      net_margin > 0.05 -> 45
      net_margin > 0 -> 30
      true -> 15
    end

    op_score = cond do
      is_nil(op_margin) -> 50
      op_margin > 0.25 -> 85
      op_margin > 0.15 -> 65
      op_margin > 0.08 -> 45
      op_margin > 0 -> 30
      true -> 15
    end

    (roe_score * 0.4 + margin_score * 0.3 + op_score * 0.3)
  end

  defp health_score(ratios) do
    cr = safe_num(ratios.current_ratio)
    de = safe_num(ratios.debt_to_equity)
    ic = safe_num(ratios.interest_coverage)

    cr_score = cond do
      is_nil(cr) -> 50
      cr > 2.0 -> 85
      cr > 1.5 -> 70
      cr > 1.0 -> 55
      cr > 0.5 -> 35
      true -> 15
    end

    de_score = cond do
      is_nil(de) -> 50
      de < 0.3 -> 85
      de < 0.6 -> 70
      de < 1.0 -> 55
      de < 2.0 -> 35
      true -> 15
    end

    ic_score = cond do
      is_nil(ic) -> 50
      ic > 15 -> 85
      ic > 8 -> 70
      ic > 3 -> 50
      ic > 1 -> 30
      true -> 15
    end

    (cr_score * 0.35 + de_score * 0.35 + ic_score * 0.30)
  end

  defp safe_num(nil), do: nil
  defp safe_num(n) when is_number(n), do: n
  defp safe_num(_), do: nil

  defp assessment_label(score) when score >= 70, do: "Undervalued"
  defp assessment_label(score) when score >= 40, do: "Fairly Valued"
  defp assessment_label(_), do: "Overvalued"

  defp profitability_label(score) when score >= 70, do: "Strong"
  defp profitability_label(score) when score >= 40, do: "Average"
  defp profitability_label(_), do: "Weak"

  defp health_label(score) when score >= 70, do: "Healthy"
  defp health_label(score) when score >= 40, do: "Average"
  defp health_label(_), do: "Weak"
end

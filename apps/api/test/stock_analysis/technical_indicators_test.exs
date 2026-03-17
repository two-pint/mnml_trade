defmodule StockAnalysis.TechnicalIndicatorsTest do
  use ExUnit.Case, async: true

  alias StockAnalysis.TechnicalIndicators

  describe "rsi/2" do
    test "returns nil when fewer than period+1 prices given" do
      assert TechnicalIndicators.rsi(Enum.to_list(1..14), 14) == nil
      assert TechnicalIndicators.rsi([], 14) == nil
    end

    test "returns 0.0 for a perfect downtrend (all losses)" do
      # Most-recent price is LOW (1.0), oldest is HIGH (30.0) → prices have been falling
      closes = Enum.map(1..30, &(&1 * 1.0))
      rsi = TechnicalIndicators.rsi(closes, 14)
      assert is_float(rsi)
      assert rsi < 30
    end

    test "returns 100.0 for a perfect uptrend (no losses)" do
      # Most-recent price is HIGH (30.0), oldest is LOW (1.0) → prices have been rising
      closes = Enum.map(30..1//-1, &(&1 * 1.0))
      rsi = TechnicalIndicators.rsi(closes, 14)
      assert rsi == 100.0
    end

    test "returns ~50 for alternating up/down prices" do
      # [101, 100, 101, 100, ...] — equal gains and losses
      closes =
        1..30
        |> Enum.map(fn i -> if rem(i, 2) == 0, do: 100.0, else: 101.0 end)

      rsi = TechnicalIndicators.rsi(closes, 14)
      assert is_float(rsi)
      assert rsi >= 40 and rsi <= 60
    end

    test "result is between 0 and 100" do
      closes = Enum.map(1..30, fn _ -> :rand.uniform() * 100 end)
      rsi = TechnicalIndicators.rsi(closes, 14)
      assert rsi >= 0 and rsi <= 100
    end
  end

  describe "sma/2" do
    test "returns nil when fewer than period prices given" do
      assert TechnicalIndicators.sma([1.0, 2.0], 3) == nil
      assert TechnicalIndicators.sma([], 1) == nil
    end

    test "returns correct average of most-recent period prices" do
      closes = [10.0, 9.0, 8.0, 7.0, 6.0]
      assert TechnicalIndicators.sma(closes, 3) == 9.0
      assert TechnicalIndicators.sma(closes, 5) == 8.0
    end

    test "ignores prices beyond the period" do
      # [100, 1, 1, 1, ...] — SMA(1) = 100, SMA(2) uses only first 2
      closes = [100.0 | List.duplicate(1.0, 10)]
      assert TechnicalIndicators.sma(closes, 1) == 100.0
      assert_in_delta TechnicalIndicators.sma(closes, 2), 50.5, 0.001
    end
  end

  describe "macd/4" do
    test "returns nil when fewer than slow+signal prices given" do
      assert TechnicalIndicators.macd(Enum.to_list(1..34) |> Enum.map(&(&1 * 1.0)), 12, 26, 9) == nil
    end

    test "returns map with macd/signal/histogram for sufficient data" do
      # 40 prices, slight uptrend (most-recent=40, oldest=1)
      closes = Enum.map(40..1//-1, &(&1 * 1.0))
      result = TechnicalIndicators.macd(closes, 12, 26, 9)
      assert is_map(result)
      assert is_float(result.macd)
      assert is_float(result.signal)
      assert is_float(result.histogram)
      assert_in_delta result.histogram, result.macd - result.signal, 0.001
    end

    test "histogram is macd minus signal" do
      closes = Enum.map(1..50, fn i -> 100.0 + :math.sin(i / 3.0) * 10 end) |> Enum.reverse()
      result = TechnicalIndicators.macd(closes)
      if result do
        assert_in_delta result.histogram, result.macd - result.signal, 0.0001
      end
    end
  end

  describe "bbands/3" do
    test "returns nil when fewer than period prices given" do
      assert TechnicalIndicators.bbands(List.duplicate(100.0, 19), 20) == nil
    end

    test "upper > middle > lower for any non-constant series" do
      closes = [105.0, 103.0, 98.0, 100.0, 102.0, 99.0, 101.0, 104.0,
                97.0, 103.0, 100.0, 101.0, 99.0, 102.0, 98.0, 100.0,
                103.0, 101.0, 99.0, 102.0]
      result = TechnicalIndicators.bbands(closes)
      assert is_map(result)
      assert result.upper > result.middle
      assert result.middle > result.lower
    end

    test "upper == middle == lower for constant prices" do
      closes = List.duplicate(100.0, 20)
      result = TechnicalIndicators.bbands(closes)
      assert result.upper == result.middle
      assert result.middle == result.lower
      assert result.middle == 100.0
    end

    test "middle equals SMA of the period" do
      closes = [10.0, 9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0,
                10.0, 9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0]
      result = TechnicalIndicators.bbands(closes, 20)
      expected_mean = Enum.sum(closes) / 20
      assert_in_delta result.middle, expected_mean, 0.0001
    end
  end

  describe "stoch/5" do
    test "returns nil when insufficient data" do
      highs = List.duplicate(100.0, 10)
      lows = List.duplicate(0.0, 10)
      closes = List.duplicate(50.0, 10)
      # k_period=14 needs 14+3-1=16 points
      assert TechnicalIndicators.stoch(highs, lows, closes, 14, 3) == nil
    end

    test "returns k=0 when close equals lowest low" do
      n = 17
      highs = List.duplicate(100.0, n)
      lows = List.duplicate(0.0, n)
      closes = List.duplicate(0.0, n)
      result = TechnicalIndicators.stoch(highs, lows, closes)
      assert result.k == 0.0
    end

    test "returns k=100 when close equals highest high" do
      n = 17
      highs = List.duplicate(100.0, n)
      lows = List.duplicate(0.0, n)
      closes = List.duplicate(100.0, n)
      result = TechnicalIndicators.stoch(highs, lows, closes)
      assert result.k == 100.0
    end

    test "returns k and d as floats in [0, 100]" do
      n = 20
      highs = Enum.map(1..n, fn i -> 100.0 + i * 0.5 end) |> Enum.reverse()
      lows = Enum.map(1..n, fn i -> 90.0 + i * 0.3 end) |> Enum.reverse()
      closes = Enum.map(1..n, fn i -> 95.0 + i * 0.4 end) |> Enum.reverse()
      result = TechnicalIndicators.stoch(highs, lows, closes)
      assert is_map(result)
      assert result.k >= 0 and result.k <= 100
      assert result.d >= 0 and result.d <= 100
    end
  end
end

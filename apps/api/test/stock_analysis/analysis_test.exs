defmodule StockAnalysis.AnalysisTest do
  use ExUnit.Case, async: false

  alias StockAnalysis.Analysis

  describe "compute_technical_score/2" do
    test "score is higher than neutral (50) when RSI is oversold (bullish)" do
      indicators = %{
        rsi: %{date: "2024-01-15", value: 20},
        sma_20: %{date: "2024-01-15", value: 100},
        sma_50: %{date: "2024-01-15", value: 99},
        sma_200: %{date: "2024-01-15", value: 98},
        macd: %{date: "2024-01-15", value: 0.5},
        bbands: nil,
        atr: nil,
        adx: nil,
        stoch: nil
      }

      result = Analysis.compute_technical_score(indicators, 101)
      assert result.score >= 55
      assert result.signal == :bullish
    end

    test "score is lower than neutral when RSI is overbought (bearish)" do
      indicators = %{
        rsi: %{date: "2024-01-15", value: 75},
        sma_20: %{date: "2024-01-15", value: 100},
        sma_50: %{date: "2024-01-15", value: 101},
        sma_200: %{date: "2024-01-15", value: 102},
        macd: %{date: "2024-01-15", value: -0.3},
        bbands: nil,
        atr: nil,
        adx: nil,
        stoch: nil
      }

      result = Analysis.compute_technical_score(indicators, 99)
      assert result.score <= 45
      assert result.signal == :bearish
    end

    test "score is between 0 and 100" do
      indicators = %{
        rsi: %{date: "2024-01-15", value: 50},
        sma_20: nil,
        sma_50: nil,
        sma_200: nil,
        macd: nil,
        bbands: nil,
        atr: nil,
        adx: nil,
        stoch: nil
      }

      result = Analysis.compute_technical_score(indicators, 100)
      assert result.score >= 0
      assert result.score <= 100
      assert result.signal in [:bullish, :bearish, :neutral]
    end
  end
end

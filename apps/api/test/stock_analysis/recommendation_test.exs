defmodule StockAnalysis.RecommendationTest do
  use ExUnit.Case, async: true

  alias StockAnalysis.Recommendation

  describe "weighted_score/1" do
    test "all scores at 90 produce Strong Buy" do
      available = %{technical: 90, fundamental: 90, sentiment: 90, institutional: 90}
      {score, confidence} = Recommendation.weighted_score(available)
      assert score == 90
      assert confidence > 80
      assert Recommendation.score_to_label(score) == "Strong Buy"
    end

    test "all scores at 30 produce Sell" do
      available = %{technical: 30, fundamental: 30, sentiment: 30, institutional: 30}
      {score, _confidence} = Recommendation.weighted_score(available)
      assert score == 30
      assert Recommendation.score_to_label(score) == "Sell"
    end

    test "all scores at 50 produce Hold" do
      available = %{technical: 50, fundamental: 50, sentiment: 50, institutional: 50}
      {score, _confidence} = Recommendation.weighted_score(available)
      assert score == 50
      assert Recommendation.score_to_label(score) == "Hold"
    end

    test "mixed scores with proper weighting" do
      available = %{technical: 80, fundamental: 60, sentiment: 40, institutional: 20}
      {score, _confidence} = Recommendation.weighted_score(available)
      expected = round(80 * 0.30 + 60 * 0.30 + 40 * 0.20 + 20 * 0.20)
      assert score == expected
    end

    test "partial data re-weights correctly" do
      available = %{technical: 80, fundamental: 80}
      {score, confidence} = Recommendation.weighted_score(available)
      assert score == 80
      assert confidence < 100
    end

    test "single dimension still produces a score with reduced confidence" do
      available = %{technical: 70}
      {score, confidence} = Recommendation.weighted_score(available)
      assert score == 70
      full = %{technical: 70, fundamental: 70, sentiment: 70, institutional: 70}
      {_, full_conf} = Recommendation.weighted_score(full)
      assert confidence < full_conf
    end

    test "high agreement produces higher confidence" do
      uniform = %{technical: 75, fundamental: 75, sentiment: 75, institutional: 75}
      {_, high_conf} = Recommendation.weighted_score(uniform)

      divergent = %{technical: 10, fundamental: 90, sentiment: 10, institutional: 90}
      {_, low_conf} = Recommendation.weighted_score(divergent)

      assert high_conf > low_conf
    end
  end

  describe "score_to_label/1" do
    test "maps score bands correctly" do
      assert Recommendation.score_to_label(95) == "Strong Buy"
      assert Recommendation.score_to_label(80) == "Strong Buy"
      assert Recommendation.score_to_label(70) == "Buy"
      assert Recommendation.score_to_label(60) == "Buy"
      assert Recommendation.score_to_label(50) == "Hold"
      assert Recommendation.score_to_label(40) == "Hold"
      assert Recommendation.score_to_label(30) == "Sell"
      assert Recommendation.score_to_label(20) == "Sell"
      assert Recommendation.score_to_label(10) == "Strong Sell"
      assert Recommendation.score_to_label(0) == "Strong Sell"
    end
  end
end

defmodule StockAnalysis.Recommendation do
  @moduledoc """
  Computes a weighted recommendation (Strong Buy / Buy / Hold / Sell / Strong Sell)
  with confidence score by combining four analysis dimensions:

  - Technical  (30%)
  - Fundamental (30%)
  - Sentiment  (20%)
  - Institutional / smart money (20%)

  Handles partial data gracefully: when a sub-score is unavailable the remaining
  scores are re-weighted and confidence is reduced.
  """
  require Logger

  alias StockAnalysis.Analysis
  alias StockAnalysis.Cache
  alias StockAnalysis.Sentiment
  alias StockAnalysis.InstitutionalActivity

  @weights %{
    technical: 0.30,
    fundamental: 0.30,
    sentiment: 0.20,
    institutional: 0.20
  }

  @doc """
  Computes the overall recommendation for a ticker by fetching all sub-scores
  (may trigger API calls if data is not cached).

  Returns `{:ok, %{recommendation: label, recommendation_score: 0-100, confidence: 0-100, components: map}}`
  or `{:error, :not_found}` if no sub-scores are available.
  """
  def compute(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))

    components = %{
      technical: fetch_technical_score(ticker),
      fundamental: fetch_fundamental_score(ticker),
      sentiment: fetch_sentiment_score(ticker),
      institutional: fetch_institutional_score(ticker)
    }

    build_result(components)
  end

  @doc """
  Computes a recommendation using only already-cached sub-scores. Never triggers
  new API calls — returns `{:error, :not_found}` if no cached data exists.

  Use this in hot paths (e.g. the stock overview endpoint) to avoid cascading
  API calls that would overwhelm rate-limited upstream services.
  """
  def compute_from_cache(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))

    components = %{
      technical: cached_score("analysis", ticker, "technical", :score),
      fundamental: cached_score("analysis", ticker, "fundamental", :score),
      sentiment: cached_sentiment_score(ticker),
      institutional: cached_institutional_score(ticker)
    }

    build_result(components)
  end

  defp build_result(components) do
    available = components |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> Map.new()

    if map_size(available) == 0 do
      {:error, :not_found}
    else
      {score, confidence} = weighted_score(available)

      {:ok, %{
        recommendation: score_to_label(score),
        recommendation_score: score,
        confidence: confidence,
        components: components
      }}
    end
  end

  @doc """
  Pure computation: given a map of `%{technical: n, fundamental: n, ...}` (any subset),
  returns `{score, confidence}`.
  """
  def weighted_score(available) when is_map(available) do
    total_weight = available |> Map.keys() |> Enum.map(&Map.fetch!(@weights, &1)) |> Enum.sum()

    score =
      available
      |> Enum.reduce(0, fn {dim, val}, acc ->
        w = Map.fetch!(@weights, dim)
        acc + val * (w / total_weight)
      end)
      |> round()
      |> max(0)
      |> min(100)

    available_count = map_size(available)
    total_count = map_size(@weights)

    data_confidence = round(available_count / total_count * 100)

    scores = Map.values(available)
    mean = Enum.sum(scores) / length(scores)
    variance = Enum.sum(Enum.map(scores, fn s -> (s - mean) * (s - mean) end)) / length(scores)
    max_variance = 2500.0
    agreement = round(max(0, (1 - variance / max_variance)) * 100)

    confidence = round(data_confidence * 0.4 + agreement * 0.6) |> max(0) |> min(100)

    {score, confidence}
  end

  def score_to_label(score) when score >= 80, do: "Strong Buy"
  def score_to_label(score) when score >= 60, do: "Buy"
  def score_to_label(score) when score >= 40, do: "Hold"
  def score_to_label(score) when score >= 20, do: "Sell"
  def score_to_label(_), do: "Strong Sell"

  ## Private: fetch sub-scores (graceful nil on failure)

  defp fetch_technical_score(ticker) do
    case Analysis.get_technical(ticker) do
      {:ok, %{score: score}} when is_number(score) -> score
      _ -> nil
    end
  end

  defp fetch_fundamental_score(ticker) do
    case Analysis.get_fundamental(ticker) do
      {:ok, %{score: score}} when is_number(score) -> score
      _ -> nil
    end
  end

  defp fetch_sentiment_score(ticker) do
    case Sentiment.get_sentiment(ticker) do
      {:ok, %{score: score}} when is_number(score) -> normalize_sentiment(score)
      _ -> nil
    end
  end

  defp fetch_institutional_score(ticker) do
    case InstitutionalActivity.get_smart_money_score(ticker) do
      {:ok, %{score: score}} when is_number(score) -> score
      _ -> nil
    end
  end

  defp normalize_sentiment(score) when score >= -100 and score <= 100 do
    round((score + 100) / 2)
  end
  defp normalize_sentiment(score) when is_number(score), do: max(0, min(100, score))

  ## Private: cache-only score lookups (no API calls)

  defp cached_score(scope, ticker, data_type, score_key) do
    cache_key = Cache.key(scope, ticker, data_type)
    case Cache.get(cache_key) do
      %{^score_key => score} when is_number(score) -> score
      _ -> nil
    end
  end

  defp cached_sentiment_score(ticker) do
    cache_key = Cache.key("sentiment", ticker, "aggregated")
    case Cache.get(cache_key) do
      %{score: score} when is_number(score) -> normalize_sentiment(score)
      _ -> nil
    end
  end

  defp cached_institutional_score(ticker) do
    cache_key = Cache.key("institutional", ticker, "basic")
    case Cache.get(cache_key) do
      %{options_flow: flow, dark_pool: dp} ->
        cong_key = Cache.key("institutional", ticker, "congressional")
        insider_key = Cache.key("institutional", ticker, "insider")
        cong = Cache.get(cong_key)
        insider = Cache.get(insider_key)
        %{score: score} = InstitutionalActivity.compute_smart_money_score(flow || [], dp || %{}, cong, insider)
        score
      _ ->
        nil
    end
  end
end

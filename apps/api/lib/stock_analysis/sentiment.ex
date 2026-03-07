defmodule StockAnalysis.Sentiment do
  @moduledoc """
  Context for sentiment analysis: aggregates Reddit posts and Finnhub news,
  runs each through a keyword-based sentiment classifier, and produces an
  overall sentiment score (-100 to +100), trend, and labeled items.

  The keyword engine can be replaced with an LLM-based classifier later
  (see M6 multi-agent analysis).
  """
  alias StockAnalysis.Cache
  alias StockAnalysis.Integrations.Reddit
  alias StockAnalysis.Integrations.Finnhub

  @bullish_keywords ~w(
    bullish buy calls moon rocket rally surge breakout beat earnings
    upgrade outperform strong growth revenue profit opportunity undervalued
    accumulate long upside catalyst positive dividend momentum
  )

  @bearish_keywords ~w(
    bearish sell puts crash dump tank plunge miss downgrade underperform
    weak decline loss overvalued short downside risk negative debt
    recession layoff lawsuit warning fraud bubble correction
  )

  @doc """
  Fetches aggregated sentiment for a ticker.

  Uses cache (30min TTL); on miss fetches Reddit + Finnhub, classifies each,
  aggregates, and caches.

  Returns `{:ok, sentiment}` with `:score` (-100..+100), `:label`, `:trend`,
  `:mention_count`, `:top_posts`, `:news`, or `{:error, :not_found}`.
  """
  def get_sentiment(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    cache_key = Cache.key("sentiment", ticker, "aggregate")
    ttl = Cache.default_ttl(:sentiment)

    case Cache.get(cache_key) do
      nil ->
        fetch_and_cache_sentiment(ticker, cache_key, ttl)

      cached ->
        {:ok, cached}
    end
  end

  @doc """
  Classifies a single text as `:bullish`, `:bearish`, or `:neutral` with a
  confidence score (0.0-1.0).

  Uses keyword frequency analysis. Designed to be replaceable with an LLM
  classifier in a future milestone.
  """
  def classify_text(text) when is_binary(text) do
    words = text |> String.downcase() |> String.split(~r/[^a-z]+/, trim: true)

    bull_count = Enum.count(words, &(&1 in @bullish_keywords))
    bear_count = Enum.count(words, &(&1 in @bearish_keywords))
    total = bull_count + bear_count

    cond do
      total == 0 ->
        %{label: :neutral, confidence: 0.5, raw_score: 0}

      bull_count > bear_count ->
        confidence = bull_count / max(total, 1)
        %{label: :bullish, confidence: Float.round(confidence, 2), raw_score: bull_count - bear_count}

      bear_count > bull_count ->
        confidence = bear_count / max(total, 1)
        %{label: :bearish, confidence: Float.round(confidence, 2), raw_score: -(bear_count - bull_count)}

      true ->
        %{label: :neutral, confidence: 0.5, raw_score: 0}
    end
  end

  def classify_text(_), do: %{label: :neutral, confidence: 0.5, raw_score: 0}

  ## Private

  defp fetch_and_cache_sentiment(ticker, cache_key, ttl) do
    posts = safe_fetch(fn -> Reddit.get_posts(ticker) end, [])
    articles = safe_fetch(fn -> Finnhub.get_news(ticker) end, [])

    if Enum.empty?(posts) and Enum.empty?(articles) do
      {:error, :not_found}
    else
      labeled_posts = label_posts(posts)
      labeled_news = label_articles(articles)

      score = compute_aggregate_score(labeled_posts, labeled_news)
      mention_count = length(posts) + length(articles)

      sentiment = %{
        ticker: ticker,
        score: score,
        label: score_to_label(score),
        trend: compute_trend(labeled_posts),
        mention_count: mention_count,
        top_posts: top_items(labeled_posts, 10),
        news: top_items(labeled_news, 10)
      }

      Cache.put(cache_key, sentiment, ttl)
      {:ok, sentiment}
    end
  end

  defp safe_fetch(fun, default) do
    case fun.() do
      {:ok, data} -> data
      {:error, _} -> default
    end
  end

  defp label_posts(posts) do
    Enum.map(posts, fn post ->
      text = "#{post.title} #{post.body}"
      classification = classify_text(text)

      Map.merge(post, %{
        sentiment: classification.label,
        sentiment_confidence: classification.confidence
      })
    end)
  end

  defp label_articles(articles) do
    Enum.map(articles, fn article ->
      text = "#{article.headline} #{article.summary}"
      classification = classify_text(text)

      Map.merge(article, %{
        sentiment: classification.label,
        sentiment_confidence: classification.confidence
      })
    end)
  end

  defp compute_aggregate_score(posts, articles) do
    post_scores = weighted_post_scores(posts)
    article_scores = Enum.map(articles, &item_score/1)

    all_scores = post_scores ++ article_scores

    if Enum.empty?(all_scores) do
      0
    else
      avg = Enum.sum(all_scores) / length(all_scores)
      round(max(-100, min(100, avg)))
    end
  end

  defp weighted_post_scores(posts) do
    Enum.map(posts, fn post ->
      base = item_score(post)
      engagement = (post[:score] || 0) + (post[:num_comments] || 0)
      weight = :math.log(max(engagement, 1) + 1)
      base * weight
    end)
  end

  defp item_score(%{sentiment: :bullish, sentiment_confidence: conf}), do: 50 * conf
  defp item_score(%{sentiment: :bearish, sentiment_confidence: conf}), do: -50 * conf
  defp item_score(_), do: 0.0

  defp compute_trend(posts) do
    now = System.system_time(:second)
    one_day = 86_400
    seven_days = 7 * one_day

    recent = Enum.filter(posts, fn p ->
      ts = p[:created_utc] || 0
      now - ts < one_day
    end)

    older = Enum.filter(posts, fn p ->
      ts = p[:created_utc] || 0
      now - ts >= one_day and now - ts < seven_days
    end)

    recent_avg = avg_sentiment(recent)
    older_avg = avg_sentiment(older)

    cond do
      recent_avg > older_avg + 10 -> "improving"
      recent_avg < older_avg - 10 -> "declining"
      true -> "stable"
    end
  end

  defp avg_sentiment([]), do: 0.0

  defp avg_sentiment(items) do
    scores = Enum.map(items, &item_score/1)
    Enum.sum(scores) / length(scores)
  end

  defp top_items(items, limit) do
    items
    |> Enum.sort_by(fn item -> -(Map.get(item, :score, 0) + Map.get(item, :num_comments, 0)) end)
    |> Enum.take(limit)
  end

  defp score_to_label(score) when score > 20, do: "Bullish"
  defp score_to_label(score) when score < -20, do: "Bearish"
  defp score_to_label(_), do: "Neutral"
end

defmodule StockAnalysisWeb.StocksController do
  use StockAnalysisWeb, :controller

  alias StockAnalysis.Analysis
  alias StockAnalysis.InstitutionalActivity
  alias StockAnalysis.Recommendation
  alias StockAnalysis.Sentiment
  alias StockAnalysis.Stocks

  def trending(conn, _params) do
    case Stocks.get_trending() do
      {:ok, list} ->
        conn
        |> put_status(:ok)
        |> json(list)

      {:error, _} ->
        conn
        |> put_status(:ok)
        |> json([])
    end
  end

  def search(conn, params) do
    q = params["q"] || ""
    case Stocks.search(q) do
      {:ok, results} ->
        conn
        |> put_status(:ok)
        |> json(results)

      {:error, :rate_limit} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "service_unavailable", message: "Search temporarily unavailable"})

      {:error, reason} when reason in [:server_error, :invalid_response, :api_key_missing] ->
        conn
        |> put_status(:bad_gateway)
        |> json(%{error: "bad_gateway", message: "Search service error"})

      {:error, _reason} ->
        # :not_found or other — degrade gracefully with empty results
        conn
        |> put_status(:ok)
        |> json([])
    end
  end

  def institutional(conn, %{"ticker" => ticker}) do
    case InstitutionalActivity.get_basic(ticker) do
      {:ok, data} ->
        conn
        |> put_status(:ok)
        |> json(data)

      {:error, :rate_limit} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "service_unavailable", message: "Institutional data temporarily unavailable"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Institutional data not found"})
    end
  end

  def daily(conn, %{"ticker" => ticker}) do
    case Stocks.get_daily(ticker) do
      {:ok, series} ->
        conn
        |> put_status(:ok)
        |> json(series)

      {:error, :rate_limit} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "service_unavailable", message: "Daily data temporarily unavailable — API rate limit reached."})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Stock not found"})
    end
  end

  def technical(conn, %{"ticker" => ticker}) do
    case Analysis.get_technical(ticker) do
      {:ok, technical} ->
        conn
        |> put_status(:ok)
        |> json(technical)

      {:error, :rate_limit} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "service_unavailable", message: "Technical data temporarily unavailable — API rate limit reached."})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Stock not found"})
    end
  end

  def sentiment(conn, %{"ticker" => ticker}) do
    case Sentiment.get_sentiment(ticker) do
      {:ok, sentiment} ->
        conn
        |> put_status(:ok)
        |> json(sentiment)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "No sentiment data found"})
    end
  end

  def fundamental(conn, %{"ticker" => ticker}) do
    case Analysis.get_fundamental(ticker) do
      {:ok, fundamental} ->
        conn
        |> put_status(:ok)
        |> json(fundamental)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Stock not found"})
    end
  end

  def show(conn, %{"ticker" => ticker}) do
    case Stocks.get_overview(ticker) do
      {:ok, overview} ->
        user = Guardian.Plug.current_resource(conn)
        if user, do: Task.start(fn -> StockAnalysis.Engagement.record_view(user.id, ticker) end)

        enriched = enrich_with_recommendation(overview, ticker)
        conn
        |> put_status(:ok)
        |> json(enriched)

      {:error, :rate_limit} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "service_unavailable", message: "Stock data temporarily unavailable — API rate limit reached. Try again in a minute."})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Stock not found"})
    end
  end

  defp enrich_with_recommendation(overview, ticker) do
    case Recommendation.compute_from_cache(ticker) do
      {:ok, rec} ->
        Map.merge(overview, %{
          recommendation: rec.recommendation,
          recommendation_score: rec.recommendation_score,
          confidence: rec.confidence,
          sub_scores: %{
            technical: rec.components[:technical],
            fundamental: rec.components[:fundamental],
            sentiment: rec.components[:sentiment],
            institutional: rec.components[:institutional]
          }
        })

      {:error, _} ->
        overview
    end
  end
end

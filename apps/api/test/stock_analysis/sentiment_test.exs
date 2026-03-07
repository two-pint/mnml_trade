defmodule StockAnalysis.SentimentTest do
  use ExUnit.Case, async: false

  alias StockAnalysis.Sentiment

  describe "classify_text/1" do
    test "classifies bullish text" do
      result = Sentiment.classify_text("I'm bullish on this stock, huge rally incoming, buy calls!")
      assert result.label == :bullish
      assert result.confidence > 0.5
      assert result.raw_score > 0
    end

    test "classifies bearish text" do
      result = Sentiment.classify_text("This stock will crash, sell everything, puts are printing")
      assert result.label == :bearish
      assert result.confidence > 0.5
      assert result.raw_score < 0
    end

    test "classifies neutral text" do
      result = Sentiment.classify_text("The company held its quarterly meeting today")
      assert result.label == :neutral
    end

    test "handles empty text" do
      result = Sentiment.classify_text("")
      assert result.label == :neutral
      assert result.confidence == 0.5
    end

    test "handles nil" do
      result = Sentiment.classify_text(nil)
      assert result.label == :neutral
    end

    test "handles mixed sentiment" do
      result = Sentiment.classify_text("Could buy or sell, bullish and bearish arguments exist")
      assert result.label in [:bullish, :bearish, :neutral]
    end
  end

  describe "get_sentiment/1 with mocked integrations" do
    setup do
      reddit_bypass = Bypass.open()
      finnhub_bypass = Bypass.open()

      Application.put_env(:stock_analysis, :reddit_base_url, "http://localhost:#{reddit_bypass.port}")
      Application.put_env(:stock_analysis, :finnhub_base_url, "http://localhost:#{finnhub_bypass.port}/api/v1")
      Application.put_env(:stock_analysis, :finnhub_api_key, "test_key")

      on_exit(fn ->
        Application.delete_env(:stock_analysis, :reddit_base_url)
        Application.delete_env(:stock_analysis, :finnhub_base_url)
        Application.delete_env(:stock_analysis, :finnhub_api_key)
        StockAnalysis.Cache.delete("sentiment:AAPL:aggregate")
        StockAnalysis.Cache.delete("sentiment:XYZNODATA:aggregate")
      end)

      {:ok, reddit: reddit_bypass, finnhub: finnhub_bypass}
    end

    test "returns aggregated sentiment with posts and news", %{reddit: reddit, finnhub: finnhub} do
      Bypass.expect(reddit, fn conn ->
        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
          "data" => %{
            "children" => [
              %{"data" => %{
                "title" => "AAPL bullish rally incoming!",
                "selftext" => "Buy calls, this stock is going to moon",
                "score" => 500,
                "num_comments" => 50,
                "created_utc" => System.system_time(:second) - 3600,
                "permalink" => "/r/wallstreetbets/comments/abc/",
                "url" => "https://reddit.com/abc"
              }}
            ]
          }
        }))
      end)

      Bypass.expect(finnhub, fn conn ->
        Plug.Conn.send_resp(conn, 200, Jason.encode!([
          %{
            "headline" => "Apple reports strong growth and record revenue",
            "summary" => "Profit beat expectations with strong momentum",
            "source" => "Reuters",
            "datetime" => System.system_time(:second) - 7200,
            "url" => "https://reuters.com/aapl",
            "sentiment" => "positive"
          }
        ]))
      end)

      assert {:ok, sentiment} = Sentiment.get_sentiment("AAPL")
      assert sentiment.ticker == "AAPL"
      assert sentiment.score >= -100 and sentiment.score <= 100
      assert sentiment.label in ["Bullish", "Bearish", "Neutral"]
      assert sentiment.trend in ["improving", "declining", "stable"]
      assert sentiment.mention_count > 0
      assert length(sentiment.top_posts) > 0
      assert length(sentiment.news) > 0

      first_post = List.first(sentiment.top_posts)
      assert first_post.sentiment in [:bullish, :bearish, :neutral]
    end

    test "returns cached result on second call", %{reddit: reddit, finnhub: finnhub} do
      Bypass.expect(reddit, fn conn ->
        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
          "data" => %{
            "children" => [
              %{"data" => %{
                "title" => "AAPL moon",
                "selftext" => "buy",
                "score" => 10,
                "num_comments" => 1,
                "created_utc" => System.system_time(:second),
                "permalink" => "/r/stocks/comments/x/",
                "url" => "https://reddit.com/x"
              }}
            ]
          }
        }))
      end)

      Bypass.expect(finnhub, fn conn ->
        Plug.Conn.send_resp(conn, 200, "[]")
      end)

      assert {:ok, first} = Sentiment.get_sentiment("AAPL")
      assert {:ok, second} = Sentiment.get_sentiment("AAPL")
      assert first.score == second.score
      assert first.mention_count == second.mention_count
    end

    test "returns {:error, :not_found} when no data at all", %{reddit: reddit, finnhub: finnhub} do
      Bypass.expect(reddit, fn conn ->
        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"data" => %{"children" => []}}))
      end)

      Bypass.expect(finnhub, fn conn ->
        Plug.Conn.send_resp(conn, 200, "[]")
      end)

      assert Sentiment.get_sentiment("XYZNODATA") == {:error, :not_found}
    end
  end
end

defmodule StockAnalysis.Integrations.RedditTest do
  use ExUnit.Case, async: false

  alias StockAnalysis.Integrations.Reddit

  setup do
    bypass = Bypass.open()
    Application.put_env(:stock_analysis, :reddit_base_url, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      Application.delete_env(:stock_analysis, :reddit_base_url)
    end)

    {:ok, bypass: bypass}
  end

  @reddit_response %{
    "data" => %{
      "children" => [
        %{
          "data" => %{
            "title" => "AAPL earnings beat expectations",
            "selftext" => "Apple reported strong Q1 results.",
            "score" => 542,
            "num_comments" => 89,
            "created_utc" => 1_706_000_000,
            "permalink" => "/r/wallstreetbets/comments/abc123/aapl_earnings/",
            "url" => "https://reddit.com/r/wallstreetbets/comments/abc123/"
          }
        },
        %{
          "data" => %{
            "title" => "Why I'm bullish on AAPL",
            "selftext" => "",
            "score" => 120,
            "num_comments" => 34,
            "created_utc" => 1_705_900_000,
            "permalink" => "/r/wallstreetbets/comments/def456/bullish_aapl/",
            "url" => "https://reddit.com/r/wallstreetbets/comments/def456/"
          }
        }
      ]
    }
  }

  describe "get_posts/1" do
    test "returns normalized posts from subreddits", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert conn.request_path =~ "/search.json"
        assert conn.query_string =~ "q=AAPL"
        Plug.Conn.send_resp(conn, 200, Jason.encode!(@reddit_response))
      end)

      assert {:ok, posts} = Reddit.get_posts("AAPL")
      assert length(posts) > 0

      first = List.first(posts)
      assert first.title == "AAPL earnings beat expectations"
      assert first.score == 542
      assert first.num_comments == 89
      assert is_binary(first.url)
    end

    test "returns empty list for ticker with no posts", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"data" => %{"children" => []}}))
      end)

      assert {:ok, []} = Reddit.get_posts("XYZNOSTOCK")
    end

    test "handles rate limit gracefully", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 429, "")
      end)

      assert {:ok, posts} = Reddit.get_posts("AAPL")
      assert posts == []
    end

    test "handles server error gracefully", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 500, "")
      end)

      assert {:ok, posts} = Reddit.get_posts("AAPL")
      assert posts == []
    end
  end
end

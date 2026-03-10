defmodule StockAnalysis.Integrations.FinnhubTest do
  use ExUnit.Case, async: false

  alias StockAnalysis.Integrations.Finnhub

  setup do
    bypass = Bypass.open()
    Application.put_env(:stock_analysis, :finnhub_base_url, "http://localhost:#{bypass.port}/api/v1")
    Application.put_env(:stock_analysis, :finnhub_api_key, "test_finnhub_key")

    on_exit(fn ->
      Application.delete_env(:stock_analysis, :finnhub_base_url)
      Application.delete_env(:stock_analysis, :finnhub_api_key)
    end)

    {:ok, bypass: bypass}
  end

  @news_response [
    %{
      "headline" => "Apple Reports Record Revenue",
      "summary" => "Apple Inc. reported record quarterly revenue of $120B.",
      "source" => "Reuters",
      "datetime" => 1_706_000_000,
      "url" => "https://reuters.com/apple-record-revenue",
      "sentiment" => "positive"
    },
    %{
      "headline" => "Apple Faces Regulatory Pressure",
      "summary" => "EU regulators have imposed new requirements on Apple.",
      "source" => "Bloomberg",
      "datetime" => 1_705_900_000,
      "url" => "https://bloomberg.com/apple-eu-regulation",
      "sentiment" => "negative"
    }
  ]

  describe "get_news/1" do
    test "returns normalized articles on 200", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert conn.request_path =~ "/api/v1/company-news"
        assert conn.query_string =~ "symbol=AAPL"
        assert conn.query_string =~ "token=test_finnhub_key"
        Plug.Conn.send_resp(conn, 200, Jason.encode!(@news_response))
      end)

      assert {:ok, articles} = Finnhub.get_news("AAPL")
      assert length(articles) == 2

      first = List.first(articles)
      assert first.headline == "Apple Reports Record Revenue"
      assert first.source == "Reuters"
      assert first.datetime == 1_706_000_000
      assert first.sentiment_from_source == "positive"
    end

    test "returns empty list for ticker with no news", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, "[]")
      end)

      assert {:ok, []} = Finnhub.get_news("XYZNOSTOCK")
    end

    test "returns {:error, :rate_limit} on 429", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 429, "")
      end)

      assert Finnhub.get_news("AAPL") == {:error, :rate_limit}
    end

    test "returns {:error, :server_error} on 500", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 500, "")
      end)

      assert Finnhub.get_news("AAPL") == {:error, :server_error}
    end

    test "returns {:error, :api_key_missing} when key not set" do
      Application.delete_env(:stock_analysis, :finnhub_api_key)
      assert Finnhub.get_news("AAPL") == {:error, :api_key_missing}
    end
  end
end

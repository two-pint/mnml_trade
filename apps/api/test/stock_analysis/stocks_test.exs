defmodule StockAnalysis.StocksTest do
  use ExUnit.Case, async: false

  alias StockAnalysis.Stocks

  describe "search/1" do
    test "returns {:ok, []} for empty query" do
      assert Stocks.search("") == {:ok, []}
      assert Stocks.search("   ") == {:ok, []}
    end
  end

  describe "get_overview/1" do
    setup do
      bypass = Bypass.open()
      Application.put_env(:stock_analysis, :alpha_vantage_base_url, "http://localhost:#{bypass.port}/query")
      Application.put_env(:stock_analysis, :alpha_vantage_api_key, "test_key")
      on_exit(fn ->
        Application.delete_env(:stock_analysis, :alpha_vantage_base_url)
        Application.delete_env(:stock_analysis, :alpha_vantage_api_key)
      end)
      {:ok, bypass: bypass}
    end

    test "fetches and caches overview on cache miss", %{bypass: bypass} do
      # Use a unique ticker so shared ETS cache from other tests does not serve a hit
      ticker = "CACHEMISS"
      Bypass.expect(bypass, fn conn ->
        assert conn.query_string =~ "function=GLOBAL_QUOTE"
        assert conn.query_string =~ "symbol=#{ticker}"
        Plug.Conn.send_resp(conn, 200, """
        {"Global Quote": {
          "01. symbol": "#{ticker}",
          "02. open": "148",
          "03. high": "151",
          "04. low": "147",
          "05. price": "150.25",
          "06. volume": "1000000",
          "07. latest trading day": "2024-01-15",
          "08. previous close": "148.5",
          "09. change": "1.75",
          "10. change percent": "1.18%"
        }}
        """)
      end)

      assert {:ok, overview} = Stocks.get_overview(ticker)
      assert overview.ticker == ticker
      assert overview.price == 150.25
      assert overview.change == 1.75
      assert overview.volume == 1_000_000
    end

    test "returns cached overview on cache hit (no second API call)", %{bypass: bypass} do
      # Use a unique ticker so no other test has populated the cache
      ticker = "CACHEHIT"
      request_count = :counters.new(1, [])

      Bypass.expect(bypass, fn conn ->
        :counters.add(request_count, 1, 1)
        Plug.Conn.send_resp(conn, 200, """
        {"Global Quote": {
          "01. symbol": "#{ticker}",
          "02. open": "100",
          "03. high": "100",
          "04. low": "100",
          "05. price": "100",
          "06. volume": "0",
          "07. latest trading day": "2024-01-15",
          "08. previous close": "100",
          "09. change": "0",
          "10. change percent": "0%"
        }}
        """)
      end)

      assert {:ok, first} = Stocks.get_overview(ticker)
      assert {:ok, second} = Stocks.get_overview(ticker)
      assert first == second
      assert :counters.get(request_count, 1) == 1
    end

    test "returns {:error, :not_found} when Alpha Vantage returns empty quote", %{bypass: bypass} do
      ticker = "NOTFOUND1"
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"Global Quote": {}}))
      end)

      assert Stocks.get_overview(ticker) == {:error, :not_found}
    end
  end
end

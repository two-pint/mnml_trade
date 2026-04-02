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

    test "force refresh uses intraday bars from today", %{bypass: bypass} do
      ticker = "TODAY1"

      Bypass.stub(bypass, "GET", "/query", fn conn ->
        q = conn.query_string || ""

        body =
          cond do
            q =~ "function=TIME_SERIES_INTRADAY" ->
              ~s|{"Time Series (1min)": {"2026-03-17 15:59:00": {"1. open": "203.10", "2. high": "210.37", "3. low": "202.90", "4. close": "204.32", "5. volume": "111111"}, "2026-03-17 09:30:00": {"1. open": "200.08", "2. high": "200.50", "3. low": "195.72", "4. close": "200.10", "5. volume": "5000"}}}|
            q =~ "function=TIME_SERIES_DAILY" ->
              ~s|{"Time Series (Daily)": {"2026-03-17": {"1. open": "200.08", "2. high": "210.37", "3. low": "195.72", "4. close": "204.32", "5. volume": "116111"}, "2026-03-16": {"1. open": "199.00", "2. high": "201.00", "3. low": "198.00", "4. close": "200.13", "5. volume": "900000"}}}|
            true ->
              flunk("unexpected request: #{q}")
          end

        Plug.Conn.send_resp(conn, 200, body)
      end)

      assert {:ok, overview} = Stocks.get_overview(ticker, force_refresh: true)
      assert overview.latest_trading_day == "2026-03-17"
      assert overview.open == 200.08
      assert overview.high == 210.37
      assert overview.low == 195.72
      assert overview.price == 204.32
      assert overview.previous_close == 200.13
      assert overview.change == 4.19
      assert overview.change_percent == "2.0936%"
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

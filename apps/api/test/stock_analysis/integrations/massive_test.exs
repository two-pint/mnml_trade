defmodule StockAnalysis.Integrations.MassiveTest do
  use ExUnit.Case, async: false

  alias StockAnalysis.Integrations.Massive

  setup do
    bypass = Bypass.open()
    Application.put_env(:stock_analysis, :massive_base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:stock_analysis, :massive_api_key, "test_api_key")

    on_exit(fn ->
      Application.delete_env(:stock_analysis, :massive_base_url)
      Application.delete_env(:stock_analysis, :massive_api_key)
    end)

    {:ok, bypass: bypass}
  end

  describe "get_quote/1" do
    test "returns normalized quote with change from previous bar", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert conn.method == "GET"
        assert String.starts_with?(conn.request_path, "/v2/aggs/ticker/AAPL/range/1/day")

        Plug.Conn.send_resp(conn, 200, """
        {
          "results": [
            {"t": 1705363200000, "o": 149.0, "h": 152.0, "l": 148.0, "c": 150.25, "v": 1000000},
            {"t": 1705276800000, "o": 146.0, "h": 149.5, "l": 145.0, "c": 148.5, "v": 900000}
          ],
          "resultsCount": 2
        }
        """)
      end)

      assert {:ok, quote} = Massive.get_quote("AAPL")
      assert quote.symbol == "AAPL"
      assert quote.price == 150.25
      assert quote.previous_close == 148.5
      assert_in_delta quote.change, 1.75, 0.001
      assert quote.volume == 1_000_000
      assert quote.open == 149.0
      assert quote.high == 152.0
      assert quote.low == 148.0
      assert is_binary(quote.latest_trading_day)
    end

    test "returns {:error, :not_found} when results is empty", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"results": [], "resultsCount": 0}))
      end)

      assert Massive.get_quote("INVALIDXYZ") == {:error, :not_found}
    end

    test "returns {:error, :not_found} on HTTP 404", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 404, "")
      end)

      assert Massive.get_quote("AAPL") == {:error, :not_found}
    end

    test "returns {:error, :server_error} on HTTP 500", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 500, "")
      end)

      assert Massive.get_quote("AAPL") == {:error, :server_error}
    end

    test "returns {:error, :rate_limit} on HTTP 429", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 429, "")
      end)

      assert Massive.get_quote("AAPL") == {:error, :rate_limit}
    end
  end

  describe "get_daily/1" do
    test "returns normalized OHLCV bars sorted desc by date", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert String.starts_with?(conn.request_path, "/v2/aggs/ticker/AAPL/range/1/day")

        Plug.Conn.send_resp(conn, 200, """
        {
          "results": [
            {"t": 1705276800000, "o": 148.0, "h": 151.0, "l": 147.0, "c": 150.25, "v": 1000000},
            {"t": 1705190400000, "o": 146.0, "h": 149.0, "l": 145.0, "c": 148.5, "v": 900000},
            {"t": 1705104000000, "o": 145.0, "h": 147.0, "l": 144.0, "c": 146.0, "v": 800000}
          ],
          "resultsCount": 3
        }
        """)
      end)

      assert {:ok, bars} = Massive.get_daily("AAPL")
      assert length(bars) == 3

      [first | _] = bars
      assert first.close == 150.25
      assert first.open == 148.0
      assert first.high == 151.0
      assert first.low == 147.0
      assert first.volume == 1_000_000
      assert is_binary(first.date)

      # Verify descending date order
      dates = Enum.map(bars, & &1.date)
      assert dates == Enum.sort(dates, :desc)
    end

    test "returns {:error, :not_found} on 404", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 404, "")
      end)

      assert Massive.get_daily("AAPL") == {:error, :not_found}
    end

    test "returns {:error, :rate_limit} on 429", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 429, "")
      end)

      assert Massive.get_daily("AAPL") == {:error, :rate_limit}
    end
  end

  describe "get_intraday/2" do
    test "returns normalized intraday bars with datetime for minute interval", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ ~r|/v2/aggs/ticker/AAPL/range/1/minute/\d+/\d+|
        assert conn.request_path =~ "minute"

        Plug.Conn.send_resp(conn, 200, """
        {
          "results": [
            {"t": 1710000000000, "o": 172.0, "h": 172.5, "l": 171.8, "c": 172.2, "v": 50000},
            {"t": 1709999940000, "o": 171.9, "h": 172.1, "l": 171.7, "c": 172.0, "v": 48000}
          ],
          "resultsCount": 2
        }
        """)
      end)

      assert {:ok, bars} = Massive.get_intraday("AAPL")
      assert length(bars) == 2

      [first | _] = bars
      assert first.close == 172.2
      assert first.open == 172.0
      assert first.datetime =~ "2024"
      assert is_binary(first.datetime)
      dates = Enum.map(bars, & &1.datetime)
      assert dates == Enum.sort(dates, :desc)
    end

    test "uses 5-minute interval when opts specify", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert conn.request_path =~ ~r|/range/5/minute/|
        Plug.Conn.send_resp(conn, 200, ~s({"results": [], "resultsCount": 0}))
      end)

      assert {:ok, []} = Massive.get_intraday("AAPL", interval: :"5minute", days: 1)
    end

    test "returns empty list when no results", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"results": [], "resultsCount": 0}))
      end)

      assert {:ok, []} = Massive.get_intraday("AAPL")
    end

    test "returns {:error, :rate_limit} on 429", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 429, "")
      end)

      assert Massive.get_intraday("AAPL") == {:error, :rate_limit}
    end
  end

  describe "symbol_search/1" do
    test "returns normalized ticker results", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/v3/reference/tickers", fn conn ->
        assert conn.query_string =~ "search=AAPL"
        assert conn.query_string =~ "active=true"

        Plug.Conn.send_resp(conn, 200, """
        {
          "results": [
            {"ticker": "AAPL", "name": "Apple Inc.", "type": "CS", "market": "stocks", "primary_exchange": "XNAS"}
          ]
        }
        """)
      end)

      assert {:ok, results} = Massive.symbol_search("AAPL")
      assert length(results) == 1
      [first] = results
      assert first.ticker == "AAPL"
      assert first.name == "Apple Inc."
      assert first.type == "CS"
      assert first.region == "stocks"
    end

    test "returns {:ok, []} when results is empty", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/v3/reference/tickers", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"results": []}))
      end)

      assert {:ok, []} = Massive.symbol_search("ZZZZZ")
    end

    test "returns {:error, :rate_limit} on 429", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/v3/reference/tickers", fn conn ->
        Plug.Conn.send_resp(conn, 429, "")
      end)

      assert Massive.symbol_search("AAPL") == {:error, :rate_limit}
    end

    test "returns {:error, :server_error} on 500", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/v3/reference/tickers", fn conn ->
        Plug.Conn.send_resp(conn, 500, "")
      end)

      assert Massive.symbol_search("AAPL") == {:error, :server_error}
    end
  end

  describe "API key" do
    test "is sent as apiKey query param" do
      bypass = Bypass.open()
      Application.put_env(:stock_analysis, :massive_base_url, "http://localhost:#{bypass.port}")
      Application.put_env(:stock_analysis, :massive_api_key, "from_config_key")

      on_exit(fn ->
        Application.delete_env(:stock_analysis, :massive_base_url)
        Application.delete_env(:stock_analysis, :massive_api_key)
      end)

      Bypass.expect(bypass, fn conn ->
        assert conn.query_string =~ "apiKey=from_config_key"

        Plug.Conn.send_resp(conn, 200, ~s({"results": [
          {"t": 1705276800000, "o": 1.0, "h": 1.0, "l": 1.0, "c": 1.0, "v": 100},
          {"t": 1705190400000, "c": 1.0}
        ]}))
      end)

      assert {:ok, _} = Massive.get_quote("X")
    end

    test "returns {:error, :api_key_missing} when key not configured" do
      Application.delete_env(:stock_analysis, :massive_api_key)
      old_env = System.get_env("MASSIVE_API_KEY")
      System.delete_env("MASSIVE_API_KEY")

      on_exit(fn ->
        if old_env, do: System.put_env("MASSIVE_API_KEY", old_env)
        Application.put_env(:stock_analysis, :massive_api_key, "test_api_key")
      end)

      assert Massive.get_quote("AAPL") == {:error, :api_key_missing}
    end
  end
end

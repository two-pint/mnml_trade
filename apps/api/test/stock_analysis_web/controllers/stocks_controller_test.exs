defmodule StockAnalysisWeb.StocksControllerTest do
  use StockAnalysisWeb.ConnCase, async: false

  alias StockAnalysis.Accounts

  @user_attrs %{
    "email" => "stocks@example.com",
    "password" => "password123",
    "username" => "stocksuser"
  }

  setup do
    bypass = Bypass.open()
    Application.put_env(:stock_analysis, :massive_base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:stock_analysis, :massive_api_key, "test_key")
    Application.put_env(:stock_analysis, :unusual_whales_base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:stock_analysis, :unusual_whales_api_key, "test_key")

    on_exit(fn ->
      Application.delete_env(:stock_analysis, :massive_base_url)
      Application.delete_env(:stock_analysis, :massive_api_key)
      Application.delete_env(:stock_analysis, :unusual_whales_base_url)
      Application.delete_env(:stock_analysis, :unusual_whales_api_key)
    end)

    {:ok, user} = Accounts.register_user(@user_attrs)
    {:ok, token, _claims} = Accounts.issue_token(user)
    %{bypass: bypass, token: token}
  end

  # Generates 30 daily OHLCV bars (most recent = t0), suitable for RSI/SMA-20/BBands/Stoch.
  defp daily_bars_json(ticker, base_close \\ 100.0) do
    t0 = 1705363200000
    results =
      0..29
      |> Enum.map(fn i ->
        t = t0 - i * 86_400_000
        c = base_close + rem(i, 5) * 0.5
        ~s({"t": #{t}, "o": #{c - 1}, "h": #{c + 1}, "l": #{c - 2}, "c": #{c}, "v": #{1_000_000 - i * 1000}})
      end)
      |> Enum.join(",\n")

    ~s({"results": [#{results}], "resultsCount": 30, "ticker": "#{ticker}"})
  end

  describe "GET /api/stocks/search" do
    test "returns matching symbols with valid JWT", %{conn: conn, bypass: bypass, token: token} do
      Bypass.stub(bypass, "GET", "/v3/reference/tickers", fn conn ->
        assert conn.method == "GET"
        assert conn.query_string =~ "search=AAPL"

        Plug.Conn.send_resp(conn, 200, """
        {"results": [
          {"ticker": "AAPL", "name": "Apple Inc.", "type": "CS", "market": "stocks"}
        ]}
        """)
      end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/stocks/search?q=AAPL")

      assert json_response(conn, 200) == [
               %{"ticker" => "AAPL", "name" => "Apple Inc.", "type" => "CS", "region" => "stocks"}
             ]
    end

    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, "/api/stocks/search?q=AAPL")
      assert %{"error" => _} = json_response(conn, 401)
    end

    test "returns 503 when Massive.com rate limit hit", %{conn: conn, bypass: bypass, token: token} do
      Bypass.stub(bypass, "GET", "/v3/reference/tickers", fn conn ->
        Plug.Conn.send_resp(conn, 429, "")
      end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/stocks/search?q=AAPL")

      assert conn.status == 503
      assert %{"error" => "service_unavailable"} = json_response(conn, 503)
    end

    test "returns 502 when Massive.com returns server error", %{conn: conn, bypass: bypass, token: token} do
      Bypass.stub(bypass, "GET", "/v3/reference/tickers", fn conn ->
        Plug.Conn.send_resp(conn, 500, "")
      end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/stocks/search?q=AAPL")

      assert conn.status == 502
      assert %{"error" => "bad_gateway"} = json_response(conn, 502)
    end
  end

  describe "GET /api/stocks/:ticker" do
    test "returns overview with valid JWT", %{conn: conn, bypass: bypass, token: token} do
      Bypass.expect(bypass, fn conn ->
        path = conn.request_path
        body =
          cond do
            String.contains?(path, "/v2/aggs/ticker/OVW1") ->
              daily_bars_json("OVW1", 150.25)

            path == "/api/option-trades/flow-alerts" ->
              ~s({"data": []})

            String.contains?(path, "/api/darkpool/OVW1") ->
              ~s({"volume": 0, "net_buy_sell": 0, "block_trades": []})

            String.contains?(path, "/api/congressional-trading/OVW1") ->
              ~s({"data": []})

            String.contains?(path, "/api/insider-trading/OVW1") ->
              ~s({"data": []})

            true ->
              ~s({})
          end

        Plug.Conn.send_resp(conn, 200, body)
      end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/stocks/OVW1")

      data = json_response(conn, 200)
      assert data["ticker"] == "OVW1"
      assert is_number(data["price"])
      assert is_number(data["change"])
    end

    test "returns 404 for invalid ticker", %{conn: conn, bypass: bypass, token: token} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"results": [], "resultsCount": 0}))
      end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/stocks/INVALIDXYZ")

      assert conn.status == 404
      assert %{"error" => "not_found"} = json_response(conn, 404)
    end

    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, "/api/stocks/AAPL")
      assert %{"error" => _} = json_response(conn, 401)
    end
  end

  describe "GET /api/stocks/:ticker/intraday" do
    test "returns intraday bars with valid JWT", %{conn: conn, bypass: bypass, token: token} do
      Bypass.expect(bypass, fn conn ->
        assert conn.request_path =~ ~r|/v2/aggs/ticker/AAPL/range/1/minute/\d+/\d+|
        Plug.Conn.send_resp(conn, 200, """
        {"results": [
          {"t": 1710000000000, "o": 172.0, "h": 172.5, "l": 171.8, "c": 172.2, "v": 50000},
          {"t": 1709999940000, "o": 171.9, "h": 172.1, "l": 171.7, "c": 172.0, "v": 48000}
        ], "resultsCount": 2}
        """)
      end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/stocks/AAPL/intraday")

      assert conn.status == 200
      data = json_response(conn, 200)
      assert length(data) == 2
      [first | _] = data
      assert first["close"] == 172.2
      assert first["open"] == 172.0
      assert is_binary(first["datetime"])
    end

    test "returns 200 with empty list when no intraday bars", %{conn: conn, bypass: bypass, token: token} do
      Bypass.expect(bypass, fn conn ->
        assert conn.request_path =~ ~r"/v2/aggs/ticker/INVALIDXYZ/range/"
        Plug.Conn.send_resp(conn, 200, ~s({"results": [], "resultsCount": 0}))
      end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/stocks/INVALIDXYZ/intraday")

      assert conn.status == 200
      assert json_response(conn, 200) == []
    end
  end

  describe "GET /api/stocks/:ticker/technical" do
    test "returns technical analysis with indicators and score", %{conn: conn, bypass: bypass, token: token} do
      # Both get_quote and get_daily call the aggregates endpoint; return 30 bars for both
      Bypass.expect(bypass, fn conn ->
        body =
          if String.contains?(conn.request_path, "/v2/aggs/ticker/TECH1") do
            daily_bars_json("TECH1")
          else
            ~s({})
          end

        Plug.Conn.send_resp(conn, 200, body)
      end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/stocks/TECH1/technical")

      assert conn.status == 200
      data = json_response(conn, 200)
      assert data["ticker"] == "TECH1"
      assert is_map(data["indicators"])
      assert data["score"] >= 0 and data["score"] <= 100
      assert data["signal"] in ["bullish", "bearish", "neutral"]
      assert data["trend_direction"] in ["bullish", "bearish", "neutral"]
      assert %{"support" => _, "resistance" => _} = data["support_resistance"]
    end

    test "returns 404 for invalid ticker", %{conn: conn, bypass: bypass, token: token} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"results": [], "resultsCount": 0}))
      end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/stocks/INVALIDTECH/technical")

      assert conn.status == 404
      assert %{"error" => "not_found"} = json_response(conn, 404)
    end

    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, "/api/stocks/AAPL/technical")
      assert %{"error" => _} = json_response(conn, 401)
    end
  end

  describe "GET /api/stocks/:ticker/institutional" do
    test "returns options flow and dark pool with data_as_of", %{conn: conn, bypass: bypass, token: token} do
      Bypass.stub(bypass, "GET", "/api/option-trades/flow-alerts", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"data": [{"option_activity_type": "sweep", "strike": 150, "premium": 10000}]}))
      end)
      Bypass.stub(bypass, "GET", "/api/darkpool/INST1", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"volume": 1000000, "net_buy_sell": 50000, "block_trades": []}))
      end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/stocks/INST1/institutional")

      assert conn.status == 200
      data = json_response(conn, 200)
      assert data["ticker"] == "INST1"
      assert is_list(data["options_flow"])
      assert data["dark_pool"]["volume"] == 1_000_000
      assert data["data_as_of"] != nil
      assert data["stale"] == false
    end

    test "returns 404 when integration returns not_found", %{conn: conn, bypass: bypass, token: token} do
      Bypass.stub(bypass, "GET", "/api/option-trades/flow-alerts", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"data": []}))
      end)
      Bypass.stub(bypass, "GET", "/api/darkpool/NOTFOUND", fn conn ->
        Plug.Conn.send_resp(conn, 404, "")
      end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/stocks/NOTFOUND/institutional")

      assert conn.status == 404
      assert %{"error" => "not_found"} = json_response(conn, 404)
    end

    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, "/api/stocks/AAPL/institutional")
      assert %{"error" => _} = json_response(conn, 401)
    end
  end
end

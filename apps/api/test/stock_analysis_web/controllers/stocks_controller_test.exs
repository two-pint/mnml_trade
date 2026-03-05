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
    Application.put_env(:stock_analysis, :alpha_vantage_base_url, "http://localhost:#{bypass.port}/query")
    Application.put_env(:stock_analysis, :alpha_vantage_api_key, "test_key")
    Application.put_env(:stock_analysis, :unusual_whales_base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:stock_analysis, :unusual_whales_api_key, "test_key")
    on_exit(fn ->
      Application.delete_env(:stock_analysis, :alpha_vantage_base_url)
      Application.delete_env(:stock_analysis, :alpha_vantage_api_key)
      Application.delete_env(:stock_analysis, :unusual_whales_base_url)
      Application.delete_env(:stock_analysis, :unusual_whales_api_key)
    end)

    {:ok, user} = Accounts.register_user(@user_attrs)
    {:ok, token, _claims} = Accounts.issue_token(user)
    %{bypass: bypass, token: token}
  end

  describe "GET /api/stocks/search" do
    test "returns matching symbols with valid JWT", %{conn: conn, bypass: bypass, token: token} do
      Bypass.expect(bypass, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/query"
        assert conn.query_string =~ "function=SYMBOL_SEARCH"
        assert conn.query_string =~ "keywords=AAPL"
        Plug.Conn.send_resp(conn, 200, """
        {"bestMatches": [
          {"1. symbol": "AAPL", "2. name": "Apple Inc", "3. type": "Equity", "4. region": "United States"}
        ]}
        """)
      end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/stocks/search?q=AAPL")

      assert json_response(conn, 200) == [
               %{"ticker" => "AAPL", "name" => "Apple Inc", "type" => "Equity", "region" => "United States"}
             ]
    end

    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, "/api/stocks/search?q=AAPL")
      assert %{"error" => _} = json_response(conn, 401)
    end

    test "returns 503 when Alpha Vantage rate limit hit", %{conn: conn, bypass: bypass, token: token} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"Note": "API call frequency is 5 calls per minute."}))
      end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/stocks/search?q=AAPL")

      assert conn.status == 503
      assert %{"error" => "service_unavailable"} = json_response(conn, 503)
    end

    test "returns 502 when Alpha Vantage returns server error", %{conn: conn, bypass: bypass, token: token} do
      Bypass.expect(bypass, fn conn ->
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
        assert conn.query_string =~ "function=GLOBAL_QUOTE"
        assert conn.query_string =~ "symbol=AAPL"
        Plug.Conn.send_resp(conn, 200, """
        {"Global Quote": {
          "01. symbol": "AAPL",
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

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/stocks/AAPL")

      data = json_response(conn, 200)
      assert data["ticker"] == "AAPL"
      assert data["price"] == 150.25
      assert data["change"] == 1.75
      assert data["volume"] == 1_000_000
    end

    test "returns 404 for invalid ticker", %{conn: conn, bypass: bypass, token: token} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"Global Quote": {}}))
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

  describe "GET /api/stocks/:ticker/technical" do
    test "returns technical analysis with indicators and score", %{conn: conn, bypass: bypass, token: token} do
      # Single stub handles all GET /query requests (quote + 9 indicators); dispatch by function= param
      Bypass.stub(bypass, "GET", "/query", fn conn ->
        q = conn.query_string || ""
        body =
          cond do
            q =~ "function=GLOBAL_QUOTE" ->
              ~s({"Global Quote": {"01. symbol": "TECH1", "05. price": "100", "06. volume": "0", "09. change": "0", "10. change percent": "0%"}})
            q =~ "function=RSI" ->
              ~s({"Technical Analysis: RSI": {"2024-01-15": {"RSI": "45"}}})
            q =~ "function=MACD" ->
              ~s({"Technical Analysis: MACD": {"2024-01-15": {"MACD_Hist": "0.1"}}})
            q =~ "function=SMA" ->
              ~s({"Technical Analysis: SMA": {"2024-01-15": {"SMA": "99"}}})
            q =~ "function=BBANDS" ->
              ~s({"Technical Analysis: BBANDS": {"2024-01-15": {"Real Lower Band": "95", "Real Middle Band": "100", "Real Upper Band": "105"}}})
            q =~ "function=ATR" ->
              ~s({"Technical Analysis: ATR": {"2024-01-15": {"ATR": "2"}}})
            q =~ "function=ADX" ->
              ~s({"Technical Analysis: ADX": {"2024-01-15": {"ADX": "20"}}})
            q =~ "function=STOCH" ->
              ~s({"Technical Analysis: STOCH": {"2024-01-15": {"SlowK": "50", "SlowD": "50"}}})
            true ->
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
        Plug.Conn.send_resp(conn, 200, ~s({"Global Quote": {}}))
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

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
    on_exit(fn ->
      Application.delete_env(:stock_analysis, :alpha_vantage_base_url)
      Application.delete_env(:stock_analysis, :alpha_vantage_api_key)
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
end

defmodule StockAnalysis.Integrations.AlphaVantageTest do
  use ExUnit.Case, async: false

  alias StockAnalysis.Integrations.AlphaVantage

  setup do
    bypass = Bypass.open()
    Application.put_env(:stock_analysis, :alpha_vantage_base_url, "http://localhost:#{bypass.port}/query")
    Application.put_env(:stock_analysis, :alpha_vantage_api_key, "test_api_key")
    on_exit(fn ->
      Application.delete_env(:stock_analysis, :alpha_vantage_base_url)
      Application.delete_env(:stock_analysis, :alpha_vantage_api_key)
    end)
    {:ok, bypass: bypass}
  end

  describe "get_quote/1" do
    test "returns normalized quote on 200 with valid body", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/query"
        Plug.Conn.send_resp(conn, 200, """
        {"Global Quote": {
          "01. symbol": "AAPL",
          "02. open": "148.0",
          "03. high": "151.0",
          "04. low": "147.0",
          "05. price": "150.25",
          "06. volume": "1000000",
          "07. latest trading day": "2024-01-15",
          "08. previous close": "148.5",
          "09. change": "1.75",
          "10. change percent": "1.18%"
        }}
        """)
      end)

      assert {:ok, quote} = AlphaVantage.get_quote("AAPL")
      assert quote.symbol == "AAPL"
      assert quote.price == 150.25
      assert quote.change == 1.75
      assert quote.volume == 1_000_000
    end

    test "returns {:error, :not_found} when Global Quote empty", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, """
        {"Global Quote": {}}
        """)
      end)

      assert AlphaVantage.get_quote("INVALIDXYZ") == {:error, :not_found}
    end

    test "returns {:error, :not_found} when Error Message in body", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, """
        {"Error Message": "Invalid API call."}
        """)
      end)

      assert AlphaVantage.get_quote("BAD") == {:error, :not_found}
    end

    test "returns {:error, :server_error} on HTTP 500", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 500, "")
      end)

      assert AlphaVantage.get_quote("AAPL") == {:error, :server_error}
    end

    test "returns {:error, :rate_limit} when Note in body", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, """
        {"Note": "Thank you for using Alpha Vantage! Our standard API call frequency is 5 calls per minute."}
        """)
      end)

      assert AlphaVantage.get_quote("AAPL") == {:error, :rate_limit}
    end
  end

  describe "get_technical_indicator/3" do
    test "returns {:error, :unsupported_indicator} for unknown indicator" do
      assert AlphaVantage.get_technical_indicator("AAPL", :unknown, %{}) == {:error, :unsupported_indicator}
    end

    test "returns normalized RSI series with mock", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, """
        {
          "Meta Data": {"1: Symbol": "AAPL"},
          "Technical Analysis: RSI": {
            "2024-01-15": {"RSI": "55.1234"},
            "2024-01-14": {"RSI": "52.0"}
          }
        }
        """)
      end)

      assert {:ok, series} = AlphaVantage.get_technical_indicator("AAPL", :rsi, %{time_period: 14})
      assert length(series) == 2
      [first | _] = series
      assert first.date in ["2024-01-15", "2024-01-14"]
      assert first.value == 55.1234 or first.value == 52.0
    end
  end

  describe "API key" do
    test "is read from config (no hardcode)" do
      # We set alpha_vantage_api_key in setup; grep would confirm it's not in source.
      # Here we only assert that with key set, a request can be made (Bypass will receive it).
      bypass = Bypass.open()
      Application.put_env(:stock_analysis, :alpha_vantage_base_url, "http://localhost:#{bypass.port}/query")
      Application.put_env(:stock_analysis, :alpha_vantage_api_key, "from_config_key")

      Bypass.expect(bypass, fn conn ->
        assert conn.query_string =~ "apikey=from_config_key"
        Plug.Conn.send_resp(conn, 200, ~s({"Global Quote": {"01. symbol": "X", "05. price": "1", "06. volume": "0", "09. change": "0", "10. change percent": "0%"}}))
      end)

      assert {:ok, _} = AlphaVantage.get_quote("X")
    end
  end
end

defmodule StockAnalysis.Integrations.UnusualWhalesTest do
  use ExUnit.Case, async: false

  alias StockAnalysis.Integrations.UnusualWhales

  setup do
    bypass = Bypass.open()
    base = "http://localhost:#{bypass.port}"
    Application.put_env(:stock_analysis, :unusual_whales_base_url, base)
    Application.put_env(:stock_analysis, :unusual_whales_api_key, "test_uw_key")
    on_exit(fn ->
      Application.delete_env(:stock_analysis, :unusual_whales_base_url)
      Application.delete_env(:stock_analysis, :unusual_whales_api_key)
    end)
    {:ok, bypass: bypass}
  end

  describe "get_options_flow/1" do
    test "returns normalized trades on 200 with data array", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/api/option-trades/flow-alerts", fn conn ->
        assert conn.query_string =~ "ticker_symbol=AAPL"
        Plug.Conn.send_resp(conn, 200, """
        {"data": [
          {"option_activity_type": "sweep", "strike": 150, "expiration": "2024-06-21", "premium": 50000, "quantity": 100, "sentiment": "bullish"}
        ]}
        """)
      end)

      assert {:ok, trades} = UnusualWhales.get_options_flow("AAPL")
      assert length(trades) == 1
      [t | _] = trades
      assert t.type == "sweep"
      assert t.strike == 150
      assert t.expiry == "2024-06-21"
      assert t.premium == 50000
      assert t.quantity == 100
      assert t.sentiment == "bullish"
    end

    test "returns {:error, :rate_limit} on 429", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/api/option-trades/flow-alerts", fn conn ->
        Plug.Conn.send_resp(conn, 429, "")
      end)

      assert UnusualWhales.get_options_flow("AAPL") == {:error, :rate_limit}
    end
  end

  describe "get_dark_pool/1" do
    test "returns normalized dark pool on 200", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/api/darkpool/AAPL", fn conn ->
        assert conn.request_path == "/api/darkpool/AAPL"
        Plug.Conn.send_resp(conn, 200, """
        {"volume": 1000000, "net_buy_sell": 50000, "block_trades": [{"size": 10000}]}
        """)
      end)

      assert {:ok, dp} = UnusualWhales.get_dark_pool("AAPL")
      assert dp.volume == 1_000_000
      assert dp.net_buy_sell == 50_000
      assert dp.block_trades == [%{"size" => 10000}]
    end

    test "returns {:error, :not_found} on 404", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/api/darkpool/INVALID", fn conn ->
        Plug.Conn.send_resp(conn, 404, "")
      end)

      assert UnusualWhales.get_dark_pool("INVALID") == {:error, :not_found}
    end
  end
end

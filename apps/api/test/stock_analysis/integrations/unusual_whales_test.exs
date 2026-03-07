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

  describe "get_congressional/1" do
    test "returns normalized congressional trades on 200", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/api/congressional-trading/AAPL", fn conn ->
        Plug.Conn.send_resp(conn, 200, """
        {"data": [
          {"representative": "Nancy Pelosi", "transaction_type": "Purchase", "amount": "$1,000,001 - $5,000,000", "transaction_date": "2024-01-15", "party": "Democrat", "ticker": "AAPL"}
        ]}
        """)
      end)

      assert {:ok, trades} = UnusualWhales.get_congressional("AAPL")
      assert length(trades) == 1
      [t] = trades
      assert t.representative == "Nancy Pelosi"
      assert t.transaction_type == "Purchase"
      assert t.party == "Democrat"
    end

    test "returns {:error, :rate_limit} on 429", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/api/congressional-trading/AAPL", fn conn ->
        Plug.Conn.send_resp(conn, 429, "")
      end)

      assert UnusualWhales.get_congressional("AAPL") == {:error, :rate_limit}
    end
  end

  describe "get_insider_trades/1" do
    test "returns normalized insider trades on 200", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/api/insider-trading/AAPL", fn conn ->
        Plug.Conn.send_resp(conn, 200, """
        {"data": [
          {"insider_name": "Tim Cook", "title": "CEO", "transaction_type": "Sale", "shares": 75000, "price": 185.50, "value": 13912500, "filing_date": "2024-02-01"}
        ]}
        """)
      end)

      assert {:ok, trades} = UnusualWhales.get_insider_trades("AAPL")
      assert length(trades) == 1
      [t] = trades
      assert t.insider_name == "Tim Cook"
      assert t.title == "CEO"
      assert t.transaction_type == "Sale"
      assert t.shares == 75000
      assert t.price == 185.50
    end
  end

  describe "get_institutional_holdings/1" do
    test "returns normalized holdings on 200", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/api/institutional-holdings/AAPL", fn conn ->
        Plug.Conn.send_resp(conn, 200, """
        {"data": [
          {"holder": "Vanguard Group", "shares": 1300000000, "value": 240000000000, "change": 5000000, "change_percent": 0.39, "date": "2024-03-31"}
        ]}
        """)
      end)

      assert {:ok, holdings} = UnusualWhales.get_institutional_holdings("AAPL")
      assert length(holdings) == 1
      [h] = holdings
      assert h.holder == "Vanguard Group"
      assert h.shares == 1_300_000_000
    end

    test "returns {:error, :not_found} on 404", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/api/institutional-holdings/INVALID", fn conn ->
        Plug.Conn.send_resp(conn, 404, "")
      end)

      assert UnusualWhales.get_institutional_holdings("INVALID") == {:error, :not_found}
    end
  end

  describe "get_market_tide/0" do
    test "returns normalized market tide on 200", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/api/market/tide", fn conn ->
        Plug.Conn.send_resp(conn, 200, """
        {"score": 72, "call_volume": 5000000, "put_volume": 3000000}
        """)
      end)

      assert {:ok, tide} = UnusualWhales.get_market_tide()
      assert tide.score == 72
      assert tide.label == "Bullish"
      assert tide.call_volume == 5_000_000
      assert tide.put_volume == 3_000_000
      assert tide.ratio == 1.67
    end

    test "returns {:error, :server_error} on 500", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/api/market/tide", fn conn ->
        Plug.Conn.send_resp(conn, 500, "")
      end)

      assert UnusualWhales.get_market_tide() == {:error, :server_error}
    end
  end
end

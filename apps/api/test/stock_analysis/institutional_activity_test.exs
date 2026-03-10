defmodule StockAnalysis.InstitutionalActivityTest do
  use ExUnit.Case, async: false

  alias StockAnalysis.InstitutionalActivity

  setup do
    bypass = Bypass.open()
    base = "http://localhost:#{bypass.port}"
    Application.put_env(:stock_analysis, :unusual_whales_base_url, base)
    Application.put_env(:stock_analysis, :unusual_whales_api_key, "test_key")
    on_exit(fn ->
      Application.delete_env(:stock_analysis, :unusual_whales_base_url)
      Application.delete_env(:stock_analysis, :unusual_whales_api_key)
    end)
    {:ok, bypass: bypass}
  end

  describe "get_basic/1" do
    test "returns options_flow and dark_pool with data_as_of", %{bypass: bypass} do
      ticker = "INSTUNIQ1"
      Bypass.stub(bypass, "GET", "/api/option-trades/flow-alerts", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"data": [{"strike": 100, "premium": 1000}]}))
      end)
      Bypass.stub(bypass, "GET", "/api/darkpool/#{ticker}", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"volume": 500000, "net_buy_sell": 10000, "block_trades": []}))
      end)

      assert {:ok, data} = InstitutionalActivity.get_basic(ticker)
      assert data.ticker == ticker
      assert is_list(data.options_flow)
      assert data.dark_pool.volume == 500_000
      assert data.stale == false
      assert data.data_as_of != nil
      assert String.contains?(data.data_as_of, "T")
    end

    test "second call within TTL returns cached (no new request)", %{bypass: bypass} do
      call_count = :counters.new(1, [])

      Bypass.stub(bypass, "GET", "/api/option-trades/flow-alerts", fn conn ->
        :counters.add(call_count, 1, 1)
        Plug.Conn.send_resp(conn, 200, ~s({"data": []}))
      end)
      Bypass.stub(bypass, "GET", "/api/darkpool/CACHE1", fn conn ->
        :counters.add(call_count, 1, 1)
        Plug.Conn.send_resp(conn, 200, ~s({"volume": 0, "net_buy_sell": 0, "block_trades": []}))
      end)

      assert {:ok, first} = InstitutionalActivity.get_basic("CACHE1")
      assert {:ok, second} = InstitutionalActivity.get_basic("CACHE1")
      assert first.data_as_of == second.data_as_of
      assert :counters.get(call_count, 1) == 2
    end
  end

  describe "get_congressional/1" do
    test "returns congressional trades", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/api/congressional-trading/CONG1", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"data": [{"representative": "John Doe", "transaction_type": "Purchase", "party": "Republican"}]}))
      end)

      assert {:ok, result} = InstitutionalActivity.get_congressional("CONG1")
      assert result.ticker == "CONG1"
      assert length(result.trades) == 1
    end
  end

  describe "get_insider_trades/1" do
    test "returns insider trades", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/api/insider-trading/INSD1", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"data": [{"insider_name": "Tim Cook", "transaction_type": "Sale", "shares": 50000}]}))
      end)

      assert {:ok, result} = InstitutionalActivity.get_insider_trades("INSD1")
      assert result.ticker == "INSD1"
      assert length(result.trades) == 1
    end
  end

  describe "get_holdings/1" do
    test "returns institutional holdings", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/api/institutional-holdings/HOLD1", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"data": [{"holder": "BlackRock", "shares": 1000000, "value": 200000000}]}))
      end)

      assert {:ok, result} = InstitutionalActivity.get_holdings("HOLD1")
      assert result.ticker == "HOLD1"
      assert length(result.holdings) == 1
    end
  end

  describe "get_market_tide/0" do
    test "returns market tide data", %{bypass: bypass} do
      StockAnalysis.Cache.delete("institutional:_market:tide")

      Bypass.stub(bypass, "GET", "/api/market/tide", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"score": 65, "call_volume": 4000000, "put_volume": 3000000}))
      end)

      assert {:ok, tide} = InstitutionalActivity.get_market_tide()
      assert is_map(tide)
      assert tide.call_volume == 4_000_000
    end
  end

  describe "get_smart_money_score/1" do
    test "computes score from sub-signals", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/api/option-trades/flow-alerts", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"data": [{"sentiment": "bullish"}, {"sentiment": "bullish"}, {"sentiment": "bearish"}]}))
      end)
      Bypass.stub(bypass, "GET", "/api/darkpool/SMART1", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"volume": 500000, "net_buy_sell": 100000, "block_trades": []}))
      end)
      Bypass.stub(bypass, "GET", "/api/congressional-trading/SMART1", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"data": [{"transaction_type": "Purchase"}, {"transaction_type": "Purchase"}, {"transaction_type": "Sale"}]}))
      end)
      Bypass.stub(bypass, "GET", "/api/insider-trading/SMART1", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"data": [{"transaction_type": "Purchase"}]}))
      end)

      assert {:ok, result} = InstitutionalActivity.get_smart_money_score("SMART1")
      assert result.ticker == "SMART1"
      assert is_number(result.score)
      assert result.score >= 0 and result.score <= 100
      assert result.label in ["Strong Institutional Buy", "Institutional Buy", "Neutral", "Institutional Sell", "Strong Institutional Sell"]
    end
  end

  describe "get_full/1" do
    test "returns combined institutional data with smart money score", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/api/option-trades/flow-alerts", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"data": [{"sentiment": "bullish"}]}))
      end)
      Bypass.stub(bypass, "GET", "/api/darkpool/FULL1", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"volume": 500000, "net_buy_sell": 50000, "block_trades": []}))
      end)
      Bypass.stub(bypass, "GET", "/api/congressional-trading/FULL1", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"data": []}))
      end)
      Bypass.stub(bypass, "GET", "/api/insider-trading/FULL1", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"data": []}))
      end)
      Bypass.stub(bypass, "GET", "/api/institutional-holdings/FULL1", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"data": []}))
      end)
      Bypass.stub(bypass, "GET", "/api/market/tide", fn conn ->
        Plug.Conn.send_resp(conn, 200, ~s({"score": 55, "call_volume": 3000000, "put_volume": 2500000}))
      end)

      assert {:ok, data} = InstitutionalActivity.get_full("FULL1")
      assert data.ticker == "FULL1"
      assert is_list(data.options_flow)
      assert is_map(data.dark_pool)
      assert is_list(data.congressional)
      assert is_list(data.insider)
      assert is_list(data.holdings)
      assert is_map(data.market_tide)
      assert is_number(data.smart_money_score)
      assert data.smart_money_score >= 0 and data.smart_money_score <= 100
      assert data.smart_money_label in ["Strong Institutional Buy", "Institutional Buy", "Neutral", "Institutional Sell", "Strong Institutional Sell"]
      assert data.data_as_of != nil
    end
  end

  describe "compute_smart_money_score/4" do
    test "bullish signals produce high score" do
      flow = [%{sentiment: "bullish"}, %{sentiment: "bullish"}, %{sentiment: "bullish"}]
      dp = %{net_buy_sell: 100_000}
      cong = [%{transaction_type: "Purchase"}, %{transaction_type: "Purchase"}]
      insider = [%{transaction_type: "Purchase"}]

      result = InstitutionalActivity.compute_smart_money_score(flow, dp, cong, insider)
      assert result.score >= 70
      assert result.label in ["Strong Institutional Buy", "Institutional Buy"]
    end

    test "bearish signals produce low score" do
      flow = [%{sentiment: "bearish"}, %{sentiment: "bearish"}, %{sentiment: "bearish"}]
      dp = %{net_buy_sell: -100_000}
      cong = [%{transaction_type: "Sale"}, %{transaction_type: "Sale"}]
      insider = [%{transaction_type: "Sale"}, %{transaction_type: "Sale"}]

      result = InstitutionalActivity.compute_smart_money_score(flow, dp, cong, insider)
      assert result.score <= 35
      assert result.label in ["Strong Institutional Sell", "Institutional Sell"]
    end

    test "empty data defaults to neutral" do
      result = InstitutionalActivity.compute_smart_money_score([], %{}, nil, nil)
      assert result.score == 50
      assert result.label == "Neutral"
    end
  end
end

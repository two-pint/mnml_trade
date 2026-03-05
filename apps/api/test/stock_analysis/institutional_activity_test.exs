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
end

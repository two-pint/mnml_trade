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
      Application.put_env(:stock_analysis, :massive_base_url, "http://localhost:#{bypass.port}")
      Application.put_env(:stock_analysis, :massive_api_key, "test_key")

      on_exit(fn ->
        Application.delete_env(:stock_analysis, :massive_base_url)
        Application.delete_env(:stock_analysis, :massive_api_key)
      end)

      {:ok, bypass: bypass}
    end

    test "fetches and caches overview on cache miss", %{bypass: bypass} do
      ticker = "CACHEMISS"
      aggs_daily = """
      {
        "results": [
          {"t": 1705363200000, "o": 148.0, "h": 151.0, "l": 147.0, "c": 150.25, "v": 1000000},
          {"t": 1705276800000, "o": 146.0, "h": 149.0, "l": 145.0, "c": 148.5, "v": 900000}
        ],
        "resultsCount": 2
      }
      """
      aggs_minute = """
      {
        "results": [
          {"t": 1705400000000, "o": 150.0, "h": 150.5, "l": 149.8, "c": 150.42, "v": 50000}
        ],
        "resultsCount": 1
      }
      """

      handler = fn conn ->
        path = conn.request_path
        cond do
          String.contains?(path, "/v2/snapshot/") ->
            Plug.Conn.send_resp(conn, 404, "")

          String.contains?(path, "/range/1/minute/") ->
            Plug.Conn.send_resp(conn, 200, aggs_minute)

          String.contains?(path, "/range/1/day/") ->
            Plug.Conn.send_resp(conn, 200, aggs_daily)

          true ->
            raise "unexpected path: #{path}"
        end
      end

      Bypass.expect(bypass, handler)
      Bypass.expect(bypass, handler)
      Bypass.expect(bypass, handler)

      assert {:ok, overview} = Stocks.get_overview(ticker)
      assert overview.ticker == ticker
      # Price comes from latest intraday bar when snapshot fails
      assert overview.price == 150.42
      assert_in_delta overview.change, 1.92, 0.001
      assert overview.volume == 1_000_000
    end

    test "returns cached overview on cache hit (no second API call)", %{bypass: bypass} do
      ticker = "CACHEHIT"
      request_count = :counters.new(1, [])
      aggs_daily = """
      {
        "results": [
          {"t": 1705363200000, "o": 100.0, "h": 100.0, "l": 100.0, "c": 100.0, "v": 0},
          {"t": 1705276800000, "o": 100.0, "h": 100.0, "l": 100.0, "c": 100.0, "v": 0}
        ],
        "resultsCount": 2
      }
      """
      aggs_minute = ~s({"results": [{"t": 1705400000000, "o": 100.0, "h": 100.0, "l": 100.0, "c": 100.0, "v": 0}], "resultsCount": 1})

      handler = fn conn ->
        path = conn.request_path
        cond do
          String.contains?(path, "/v2/snapshot/") ->
            Plug.Conn.send_resp(conn, 404, "")

          String.contains?(path, "/range/1/minute/") ->
            :counters.add(request_count, 1, 1)
            Plug.Conn.send_resp(conn, 200, aggs_minute)

          String.contains?(path, "/range/1/day/") ->
            :counters.add(request_count, 1, 1)
            Plug.Conn.send_resp(conn, 200, aggs_daily)

          true ->
            raise "unexpected path: #{path}"
        end
      end

      Bypass.expect(bypass, handler)
      Bypass.expect(bypass, handler)
      Bypass.expect(bypass, handler)

      assert {:ok, first} = Stocks.get_overview(ticker)
      assert {:ok, second} = Stocks.get_overview(ticker)
      assert first == second
      # Snapshot 404 + quote (day) + intraday (minute) = 2 aggs requests. Second get_overview hits cache.
      assert :counters.get(request_count, 1) == 2,
             "expected 2 aggs requests (quote + intraday), got #{:counters.get(request_count, 1)}"
    end

    test "returns {:error, :not_found} when Massive returns empty results", %{bypass: bypass} do
      ticker = "NOTFOUND1"

      handler = fn conn ->
        path = conn.request_path
        cond do
          String.contains?(path, "/v2/snapshot/") ->
            Plug.Conn.send_resp(conn, 404, "")

          String.contains?(path, "/range/1/minute/") ->
            Plug.Conn.send_resp(conn, 200, ~s({"results": [], "resultsCount": 0}))

          String.contains?(path, "/range/1/day/") ->
            Plug.Conn.send_resp(conn, 200, ~s({"results": [], "resultsCount": 0}))

          true ->
            raise "unexpected path: #{path}"
        end
      end

      Bypass.expect(bypass, handler)
      Bypass.expect(bypass, handler)
      Bypass.expect(bypass, handler)

      assert Stocks.get_overview(ticker) == {:error, :not_found}
    end
  end
end

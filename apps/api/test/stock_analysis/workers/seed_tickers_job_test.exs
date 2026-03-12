defmodule StockAnalysis.Workers.SeedTickersJobTest do
  use StockAnalysis.DataCase, async: false
  use Oban.Testing, repo: StockAnalysis.Repo

  alias StockAnalysis.Workers.SeedTickersJob
  alias StockAnalysis.Market

  # We set up a Bypass server and configure the FMP base URL in setup
  # so the job's FMP calls hit our mock instead of the real API.
  setup do
    bypass = Bypass.open()
    Application.put_env(:stock_analysis, :fmp_base_url, "http://localhost:#{bypass.port}/api/v3")
    Application.put_env(:stock_analysis, :fmp_api_key, "test_fmp_key")
    StockAnalysis.Cache.delete("fmp:sp500_constituents")

    on_exit(fn ->
      Application.delete_env(:stock_analysis, :fmp_base_url)
      Application.delete_env(:stock_analysis, :fmp_api_key)
      StockAnalysis.Cache.delete("fmp:sp500_constituents")
    end)

    {:ok, bypass: bypass}
  end

  defp sp500_fixture do
    [
      %{"symbol" => "AAPL", "name" => "Apple Inc.", "sector" => "Information Technology"},
      %{"symbol" => "MSFT", "name" => "Microsoft Corp.", "sector" => "Information Technology"},
      %{"symbol" => "AMZN", "name" => "Amazon.com Inc.", "sector" => "Consumer Discretionary"}
    ]
  end

  describe "perform/1" do
    test "upserts tickers from FMP S&P 500 list", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, Jason.encode!(sp500_fixture()))
      end)

      assert :ok = perform_job(SeedTickersJob, %{})
      assert length(Market.list_active_tickers()) == 3
    end

    test "is idempotent — running twice produces same count", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/api/v3/sp500_constituent", fn conn ->
        Plug.Conn.send_resp(conn, 200, Jason.encode!(sp500_fixture()))
      end)

      assert :ok = perform_job(SeedTickersJob, %{})
      # Clear cache so second call hits the bypass again
      StockAnalysis.Cache.delete("fmp:sp500_constituents")
      assert :ok = perform_job(SeedTickersJob, %{})

      assert length(Market.list_active_tickers()) == 3
    end

    test "returns {:error, reason} when FMP call fails", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 429, "")
      end)

      assert {:error, :rate_limit} = perform_job(SeedTickersJob, %{})
    end
  end
end

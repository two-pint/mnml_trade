defmodule StockAnalysis.Integrations.FMPTest do
  use ExUnit.Case, async: false

  alias StockAnalysis.Integrations.FMP

  setup do
    bypass = Bypass.open()
    Application.put_env(:stock_analysis, :fmp_base_url, "http://localhost:#{bypass.port}/api/v3")
    Application.put_env(:stock_analysis, :fmp_api_key, "test_fmp_key")

    on_exit(fn ->
      Application.delete_env(:stock_analysis, :fmp_base_url)
      Application.delete_env(:stock_analysis, :fmp_api_key)
    end)

    {:ok, bypass: bypass}
  end

  describe "get_profile/1" do
    test "returns normalized profile on 200", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert conn.request_path =~ "/api/v3/profile/AAPL"

        Plug.Conn.send_resp(conn, 200, Jason.encode!([%{
          "symbol" => "AAPL",
          "companyName" => "Apple Inc.",
          "description" => "A technology company.",
          "sector" => "Technology",
          "industry" => "Consumer Electronics",
          "mktCap" => 3_000_000_000_000,
          "fullTimeEmployees" => 164_000,
          "ceo" => "Tim Cook",
          "city" => "Cupertino",
          "state" => "CA",
          "country" => "US",
          "website" => "https://apple.com",
          "exchangeShortName" => "NASDAQ",
          "currency" => "USD",
          "price" => 195.50,
          "beta" => 1.28,
          "volAvg" => 55_000_000,
          "lastDiv" => 0.96,
          "range" => "124.17-199.62",
          "ipoDate" => "1980-12-12",
          "image" => "https://example.com/aapl.png"
        }]))
      end)

      assert {:ok, profile} = FMP.get_profile("AAPL")
      assert profile.symbol == "AAPL"
      assert profile.company_name == "Apple Inc."
      assert profile.sector == "Technology"
      assert profile.market_cap == 3_000_000_000_000
      assert profile.employees == 164_000
    end

    test "returns {:error, :not_found} for empty list", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, "[]")
      end)

      assert FMP.get_profile("INVALIDXYZ") == {:error, :not_found}
    end

    test "returns {:error, :server_error} on HTTP 500", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 500, "")
      end)

      assert FMP.get_profile("AAPL") == {:error, :server_error}
    end
  end

  describe "get_ratios/1" do
    test "returns normalized ratios on 200", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert conn.request_path =~ "/api/v3/ratios/AAPL"

        Plug.Conn.send_resp(conn, 200, Jason.encode!([%{
          "date" => "2024-01-01",
          "priceEarningsRatio" => 28.5,
          "priceToBookRatio" => 45.2,
          "priceEarningsToGrowthRatio" => 2.1,
          "priceToSalesRatio" => 7.5,
          "returnOnEquity" => 1.47,
          "returnOnAssets" => 0.28,
          "grossProfitMargin" => 0.44,
          "operatingProfitMargin" => 0.30,
          "netProfitMargin" => 0.25,
          "currentRatio" => 0.99,
          "quickRatio" => 0.94,
          "debtEquityRatio" => 1.76,
          "interestCoverage" => 29.0,
          "dividendYield" => 0.005,
          "payoutRatio" => 0.15
        }]))
      end)

      assert {:ok, ratios} = FMP.get_ratios("AAPL")
      assert ratios.pe_ratio == 28.5
      assert ratios.roe == 1.47
      assert ratios.current_ratio == 0.99
      assert ratios.debt_to_equity == 1.76
    end

    test "returns {:error, :not_found} for empty list", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, "[]")
      end)

      assert FMP.get_ratios("INVALIDXYZ") == {:error, :not_found}
    end
  end

  describe "get_income_statement/2" do
    test "returns normalized quarterly income statements", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert conn.request_path =~ "/api/v3/income-statement/AAPL"
        assert conn.query_string =~ "period=quarter"

        Plug.Conn.send_resp(conn, 200, Jason.encode!([
          %{
            "date" => "2024-01-01",
            "period" => "Q1",
            "revenue" => 119_575_000_000,
            "costOfRevenue" => 64_720_000_000,
            "grossProfit" => 54_855_000_000,
            "operatingIncome" => 40_372_000_000,
            "netIncome" => 33_916_000_000,
            "ebitda" => 44_252_000_000,
            "eps" => 2.18,
            "epsdiluted" => 2.18,
            "operatingExpenses" => 14_483_000_000,
            "interestExpense" => 1_002_000_000
          }
        ]))
      end)

      assert {:ok, [stmt | _]} = FMP.get_income_statement("AAPL", :quarterly)
      assert stmt.date == "2024-01-01"
      assert stmt.revenue == 119_575_000_000
      assert stmt.net_income == 33_916_000_000
      assert stmt.eps == 2.18
    end

    test "returns {:error, :not_found} for empty list", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, "[]")
      end)

      assert FMP.get_income_statement("INVALIDXYZ") == {:error, :not_found}
    end
  end

  describe "get_balance_sheet/2" do
    test "returns normalized balance sheet", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert conn.request_path =~ "/api/v3/balance-sheet-statement/AAPL"

        Plug.Conn.send_resp(conn, 200, Jason.encode!([
          %{
            "date" => "2024-01-01",
            "period" => "FY",
            "totalAssets" => 352_583_000_000,
            "totalLiabilities" => 290_437_000_000,
            "totalStockholdersEquity" => 62_146_000_000,
            "totalDebt" => 111_088_000_000,
            "netDebt" => 81_123_000_000,
            "cashAndCashEquivalents" => 29_965_000_000,
            "totalCurrentAssets" => 143_566_000_000,
            "totalCurrentLiabilities" => 145_308_000_000,
            "goodwill" => 0,
            "intangibleAssets" => 0
          }
        ]))
      end)

      assert {:ok, [bs | _]} = FMP.get_balance_sheet("AAPL")
      assert bs.total_assets == 352_583_000_000
      assert bs.total_equity == 62_146_000_000
    end
  end

  describe "get_cash_flow/2" do
    test "returns normalized cash flow", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert conn.request_path =~ "/api/v3/cash-flow-statement/AAPL"

        Plug.Conn.send_resp(conn, 200, Jason.encode!([
          %{
            "date" => "2024-01-01",
            "period" => "FY",
            "operatingCashFlow" => 110_543_000_000,
            "capitalExpenditure" => -10_959_000_000,
            "freeCashFlow" => 99_584_000_000,
            "dividendsPaid" => -15_025_000_000,
            "netCashUsedProvidedByFinancingActivities" => -108_488_000_000,
            "netCashUsedForInvestingActivites" => 3_705_000_000
          }
        ]))
      end)

      assert {:ok, [cf | _]} = FMP.get_cash_flow("AAPL")
      assert cf.operating_cash_flow == 110_543_000_000
      assert cf.free_cash_flow == 99_584_000_000
    end
  end

  describe "get_sp500_constituents/0" do
    setup do
      StockAnalysis.Cache.delete("fmp:sp500_constituents")
      :ok
    end

    test "returns normalized constituent list on 200", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        assert conn.request_path =~ "/api/v3/sp500_constituent"
        Plug.Conn.send_resp(conn, 200, Jason.encode!([
          %{
            "symbol" => "AAPL",
            "name" => "Apple Inc.",
            "sector" => "Information Technology",
            "subSector" => "Technology Hardware",
            "headQuarter" => "Cupertino, CA",
            "dateFirstAdded" => "1982-11-30",
            "cik" => "0000320193",
            "founded" => "1976-04-01"
          },
          %{
            "symbol" => "MSFT",
            "name" => "Microsoft Corp.",
            "sector" => "Information Technology",
            "subSector" => "Systems Software",
            "headQuarter" => "Redmond, WA",
            "dateFirstAdded" => "1994-06-01",
            "cik" => "0000789019",
            "founded" => "1975-04-04"
          }
        ]))
      end)

      assert {:ok, constituents} = FMP.get_sp500_constituents()
      assert length(constituents) == 2
      [aapl | _] = constituents
      assert aapl.symbol == "AAPL"
      assert aapl.name == "Apple Inc."
      assert aapl.sector == "Information Technology"
    end

    test "returns cached result on second call (no second HTTP request)", %{bypass: bypass} do
      StockAnalysis.Cache.delete("fmp:sp500_constituents")
      call_count = :counters.new(1, [])

      Bypass.stub(bypass, "GET", "/api/v3/sp500_constituent", fn conn ->
        :counters.add(call_count, 1, 1)
        Plug.Conn.send_resp(conn, 200, Jason.encode!([%{
          "symbol" => "AAPL", "name" => "Apple", "sector" => "Tech"
        }]))
      end)

      {:ok, _} = FMP.get_sp500_constituents()
      {:ok, _} = FMP.get_sp500_constituents()

      assert :counters.get(call_count, 1) == 1
    end

    test "returns {:error, :not_found} for empty list", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, "[]")
      end)

      assert {:error, :not_found} = FMP.get_sp500_constituents()
    end

    test "returns {:error, :rate_limit} on 429", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 429, "")
      end)

      assert {:error, :rate_limit} = FMP.get_sp500_constituents()
    end
  end

  describe "get_bulk_quote/0" do
    setup do
      StockAnalysis.Cache.delete("fmp:bulk_quote")
      :ok
    end

    test "returns normalized bulk quote list on 200", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        assert conn.request_path =~ "/api/v3/stock/full/real-time-price"
        Plug.Conn.send_resp(conn, 200, Jason.encode!([
          %{
            "ticker" => "AAPL",
            "lastSalePrice" => 195.50,
            "volume" => 55_000_000,
            "priceChange" => 2.30,
            "priceChangePercent" => 1.19
          },
          %{
            "ticker" => "MSFT",
            "lastSalePrice" => 420.00,
            "volume" => 22_000_000,
            "priceChange" => -1.50,
            "priceChangePercent" => -0.36
          }
        ]))
      end)

      assert {:ok, quotes} = FMP.get_bulk_quote()
      assert length(quotes) == 2
      [aapl | _] = quotes
      assert aapl.symbol == "AAPL"
      assert aapl.price == 195.50
      assert aapl.volume == 55_000_000
    end

    test "returns cached result on second call", %{bypass: bypass} do
      StockAnalysis.Cache.delete("fmp:bulk_quote")
      call_count = :counters.new(1, [])

      Bypass.stub(bypass, "GET", "/api/v3/stock/full/real-time-price", fn conn ->
        :counters.add(call_count, 1, 1)
        Plug.Conn.send_resp(conn, 200, Jason.encode!([
          %{"ticker" => "AAPL", "lastSalePrice" => 195.0, "volume" => 50_000_000}
        ]))
      end)

      {:ok, _} = FMP.get_bulk_quote()
      {:ok, _} = FMP.get_bulk_quote()

      assert :counters.get(call_count, 1) == 1
    end

    test "returns empty list on empty response", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, "[]")
      end)

      assert {:ok, []} = FMP.get_bulk_quote()
    end

    test "returns {:error, :rate_limit} on 429", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 429, "")
      end)

      assert {:error, :rate_limit} = FMP.get_bulk_quote()
    end
  end

  describe "API key" do
    test "returns {:error, :api_key_missing} when key not set" do
      Application.delete_env(:stock_analysis, :fmp_api_key)

      assert FMP.get_profile("AAPL") == {:error, :api_key_missing}
    end

    test "sends apikey query param", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert conn.query_string =~ "apikey=test_fmp_key"
        Plug.Conn.send_resp(conn, 200, Jason.encode!([%{"symbol" => "X"}]))
      end)

      assert {:ok, _} = FMP.get_profile("X")
    end
  end
end

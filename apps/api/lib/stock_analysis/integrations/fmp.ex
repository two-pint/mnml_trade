defmodule StockAnalysis.Integrations.FMP do
  @moduledoc """
  Financial Modeling Prep API integration for company profiles, financial ratios,
  and financial statements (income, balance sheet, cash flow).

  API key is configured via application env or `FMP_API_KEY` (never hard-coded).
  Free tier: 250 requests/day.
  """
  require Logger

  @default_base_url "https://financialmodelingprep.com/api/v3"

  defp base_url do
    Application.get_env(:stock_analysis, :fmp_base_url, @default_base_url)
  end

  @sp500_cache_ttl 7 * 24 * 3600
  @bulk_quote_cache_ttl 15 * 60

  @doc """
  Fetches S&P 500 constituent list from FMP.

  Returns `{:ok, [%{symbol: _, name: _, sector: _, ...}]}` or `{:error, reason}`.
  Cached for 7 days since the index composition changes infrequently.
  """
  def get_sp500_constituents do
    cache_key = "fmp:sp500_constituents"

    case StockAnalysis.Cache.get(cache_key) do
      nil ->
        result =
          case get("/sp500_constituent") do
            {:ok, list} when is_list(list) and length(list) > 0 ->
              {:ok, Enum.map(list, &normalize_constituent/1)}

            {:ok, []} ->
              {:error, :not_found}

            {:ok, _} ->
              {:error, :invalid_response}

            {:error, reason} ->
              {:error, reason}
          end

        case result do
          {:ok, data} ->
            StockAnalysis.Cache.put(cache_key, data, @sp500_cache_ttl)
            {:ok, data}

          error ->
            error
        end

      cached ->
        {:ok, cached}
    end
  end

  @doc """
  Fetches a bulk real-time quote snapshot for all tracked tickers.

  Returns `{:ok, [%{symbol: _, price: _, volume: _, ...}]}` or `{:error, reason}`.
  Cached for 15 minutes.
  """
  def get_bulk_quote do
    cache_key = "fmp:bulk_quote"

    case StockAnalysis.Cache.get(cache_key) do
      nil ->
        result =
          case get("/stock/full/real-time-price") do
            {:ok, list} when is_list(list) ->
              {:ok, Enum.map(list, &normalize_bulk_quote/1)}

            {:ok, _} ->
              {:error, :invalid_response}

            {:error, reason} ->
              {:error, reason}
          end

        case result do
          {:ok, data} ->
            StockAnalysis.Cache.put(cache_key, data, @bulk_quote_cache_ttl)
            {:ok, data}

          error ->
            error
        end

      cached ->
        {:ok, cached}
    end
  end

  @doc """
  Fetches the company profile for a ticker.

  Returns `{:ok, %{description: _, sector: _, industry: _, market_cap: _, ...}}`
  or `{:error, reason}`.
  """
  def get_profile(ticker) when is_binary(ticker) do
    case get("/profile/#{encode(ticker)}") do
      {:ok, [profile | _]} when is_map(profile) ->
        {:ok, normalize_profile(profile)}

      {:ok, []} ->
        {:error, :not_found}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches key financial ratios (TTM or most recent annual).

  Returns `{:ok, %{pe_ratio: _, pb_ratio: _, roe: _, ...}}` or `{:error, reason}`.
  """
  def get_ratios(ticker) when is_binary(ticker) do
    case get("/ratios/#{encode(ticker)}", limit: 1) do
      {:ok, [ratios | _]} when is_map(ratios) ->
        {:ok, normalize_ratios(ratios)}

      {:ok, []} ->
        {:error, :not_found}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches income statements.

  `period` is `:quarterly` or `:annual`. Returns last 4 quarters or 3 years by default.
  Returns `{:ok, [%{date: _, revenue: _, ...}, ...]}` or `{:error, reason}`.
  """
  def get_income_statement(ticker, period \\ :annual) when is_binary(ticker) do
    {period_str, limit} = period_params(period)

    case get("/income-statement/#{encode(ticker)}", period: period_str, limit: limit) do
      {:ok, list} when is_list(list) and length(list) > 0 ->
        {:ok, Enum.map(list, &normalize_income_statement/1)}

      {:ok, []} ->
        {:error, :not_found}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches balance sheet statements.

  `period` is `:quarterly` or `:annual`.
  Returns `{:ok, [%{date: _, total_assets: _, ...}, ...]}` or `{:error, reason}`.
  """
  def get_balance_sheet(ticker, period \\ :annual) when is_binary(ticker) do
    {period_str, limit} = period_params(period)

    case get("/balance-sheet-statement/#{encode(ticker)}", period: period_str, limit: limit) do
      {:ok, list} when is_list(list) and length(list) > 0 ->
        {:ok, Enum.map(list, &normalize_balance_sheet/1)}

      {:ok, []} ->
        {:error, :not_found}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches cash flow statements.

  `period` is `:quarterly` or `:annual`.
  Returns `{:ok, [%{date: _, operating_cash_flow: _, ...}, ...]}` or `{:error, reason}`.
  """
  def get_cash_flow(ticker, period \\ :annual) when is_binary(ticker) do
    {period_str, limit} = period_params(period)

    case get("/cash-flow-statement/#{encode(ticker)}", period: period_str, limit: limit) do
      {:ok, list} when is_list(list) and length(list) > 0 ->
        {:ok, Enum.map(list, &normalize_cash_flow/1)}

      {:ok, []} ->
        {:error, :not_found}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Private: HTTP

  defp api_key do
    Application.get_env(:stock_analysis, :fmp_api_key) ||
      System.get_env("FMP_API_KEY")
  end

  defp get(path, extra_params \\ []) do
    key = api_key()

    if is_nil(key) or key == "" do
      Logger.warning("FMP: API key not configured")
      {:error, :api_key_missing}
    else
      url = base_url() <> path

      params =
        [{:apikey, key} | extra_params]
        |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)

      opts = [
        params: params,
        receive_timeout: 15_000,
        retry: Application.get_env(:stock_analysis, :req_retry, :transient)
      ]

      case Req.get(url, opts) do
        {:ok, %{status: 200, body: body}} ->
          parsed = maybe_decode_json(body)

          cond do
            is_list(parsed) -> {:ok, parsed}
            is_map(parsed) and Map.has_key?(parsed, "Error Message") -> {:error, :not_found}
            is_map(parsed) -> {:ok, [parsed]}
            true -> {:error, :invalid_response}
          end

        {:ok, %{status: 429}} ->
          {:error, :rate_limit}

        {:ok, %{status: 403}} ->
          {:error, :api_key_missing}

        {:ok, %{status: 404}} ->
          {:error, :not_found}

        {:ok, %{status: status}} when status >= 500 ->
          {:error, :server_error}

        {:ok, _} ->
          {:error, :invalid_response}

        {:error, _} ->
          {:error, :server_error}
      end
    end
  end

  defp maybe_decode_json(body) when is_list(body), do: body
  defp maybe_decode_json(body) when is_map(body), do: body

  defp maybe_decode_json(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, parsed} -> parsed
      _ -> nil
    end
  end

  defp maybe_decode_json(_), do: nil

  defp encode(ticker), do: URI.encode(String.upcase(String.trim(ticker)))

  defp period_params(:quarterly), do: {"quarter", 4}
  defp period_params(:annual), do: {"annual", 3}
  defp period_params(_), do: {"annual", 3}

  ## Private: normalization

  defp normalize_profile(raw) do
    %{
      symbol: raw["symbol"],
      company_name: raw["companyName"],
      description: raw["description"],
      sector: raw["sector"],
      industry: raw["industry"],
      market_cap: num_or_nil(raw["mktCap"]),
      employees: num_or_nil(raw["fullTimeEmployees"]),
      ceo: raw["ceo"],
      city: raw["city"],
      state: raw["state"],
      country: raw["country"],
      website: raw["website"],
      exchange: raw["exchangeShortName"],
      currency: raw["currency"],
      price: num_or_nil(raw["price"]),
      beta: num_or_nil(raw["beta"]),
      vol_avg: num_or_nil(raw["volAvg"]),
      last_dividend: num_or_nil(raw["lastDiv"]),
      range: raw["range"],
      ipo_date: raw["ipoDate"],
      image: raw["image"]
    }
  end

  defp normalize_ratios(raw) do
    %{
      pe_ratio: num_or_nil(raw["priceEarningsRatio"]),
      pb_ratio: num_or_nil(raw["priceToBookRatio"]),
      peg_ratio: num_or_nil(raw["priceEarningsToGrowthRatio"]),
      ps_ratio: num_or_nil(raw["priceToSalesRatio"]),
      roe: num_or_nil(raw["returnOnEquity"]),
      roa: num_or_nil(raw["returnOnAssets"]),
      gross_margin: num_or_nil(raw["grossProfitMargin"]),
      operating_margin: num_or_nil(raw["operatingProfitMargin"]),
      net_margin: num_or_nil(raw["netProfitMargin"]),
      current_ratio: num_or_nil(raw["currentRatio"]),
      quick_ratio: num_or_nil(raw["quickRatio"]),
      debt_to_equity: num_or_nil(raw["debtEquityRatio"]),
      interest_coverage: num_or_nil(raw["interestCoverage"]),
      dividend_yield: num_or_nil(raw["dividendYield"]),
      payout_ratio: num_or_nil(raw["payoutRatio"]),
      date: raw["date"]
    }
  end

  defp normalize_income_statement(raw) do
    %{
      date: raw["date"],
      period: raw["period"],
      revenue: num_or_nil(raw["revenue"]),
      cost_of_revenue: num_or_nil(raw["costOfRevenue"]),
      gross_profit: num_or_nil(raw["grossProfit"]),
      operating_income: num_or_nil(raw["operatingIncome"]),
      net_income: num_or_nil(raw["netIncome"]),
      ebitda: num_or_nil(raw["ebitda"]),
      eps: num_or_nil(raw["eps"]),
      eps_diluted: num_or_nil(raw["epsdiluted"]),
      operating_expenses: num_or_nil(raw["operatingExpenses"]),
      interest_expense: num_or_nil(raw["interestExpense"])
    }
  end

  defp normalize_balance_sheet(raw) do
    %{
      date: raw["date"],
      period: raw["period"],
      total_assets: num_or_nil(raw["totalAssets"]),
      total_liabilities: num_or_nil(raw["totalLiabilities"]),
      total_equity: num_or_nil(raw["totalStockholdersEquity"]),
      total_debt: num_or_nil(raw["totalDebt"]),
      net_debt: num_or_nil(raw["netDebt"]),
      cash_and_equivalents: num_or_nil(raw["cashAndCashEquivalents"]),
      total_current_assets: num_or_nil(raw["totalCurrentAssets"]),
      total_current_liabilities: num_or_nil(raw["totalCurrentLiabilities"]),
      goodwill: num_or_nil(raw["goodwill"]),
      intangible_assets: num_or_nil(raw["intangibleAssets"])
    }
  end

  defp normalize_constituent(raw) do
    %{
      symbol: raw["symbol"],
      name: raw["name"],
      sector: raw["sector"],
      sub_sector: raw["subSector"],
      headquarters: raw["headQuarter"],
      date_added: raw["dateFirstAdded"],
      cik: raw["cik"],
      founded: raw["founded"]
    }
  end

  defp normalize_bulk_quote(raw) do
    %{
      symbol: raw["ticker"] || raw["symbol"],
      price: num_or_nil(raw["lastSalePrice"] || raw["price"]),
      volume: num_or_nil(raw["volume"]),
      change: num_or_nil(raw["priceChange"] || raw["change"]),
      change_percent: num_or_nil(raw["priceChangePercent"] || raw["changesPercentage"])
    }
  end

  defp normalize_cash_flow(raw) do
    %{
      date: raw["date"],
      period: raw["period"],
      operating_cash_flow: num_or_nil(raw["operatingCashFlow"]),
      capital_expenditure: num_or_nil(raw["capitalExpenditure"]),
      free_cash_flow: num_or_nil(raw["freeCashFlow"]),
      dividends_paid: num_or_nil(raw["dividendsPaid"]),
      net_cash_from_financing: num_or_nil(raw["netCashUsedProvidedByFinancingActivities"]),
      net_cash_from_investing: num_or_nil(raw["netCashUsedForInvestingActivites"])
    }
  end

  defp num_or_nil(nil), do: nil
  defp num_or_nil(n) when is_number(n), do: n

  defp num_or_nil(s) when is_binary(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp num_or_nil(_), do: nil
end

defmodule StockAnalysisWeb.PortfolioJSON do
  alias StockAnalysis.PaperTrading.Portfolio

  def index(%{portfolios: portfolios}) do
    %{data: Enum.map(portfolios, &portfolio_summary/1)}
  end

  def show(%{portfolio: portfolio}) do
    %{data: portfolio_detail(portfolio)}
  end

  defp portfolio_summary(%Portfolio{} = p) do
    %{
      id: p.id,
      name: p.name,
      description: p.description,
      starting_balance: p.starting_balance,
      cash_balance: p.cash_balance,
      is_active: p.is_active,
      holdings_count: length(p.holdings),
      inserted_at: p.inserted_at,
      updated_at: p.updated_at
    }
  end

  defp portfolio_detail(%Portfolio{} = p) do
    %{
      id: p.id,
      name: p.name,
      description: p.description,
      starting_balance: p.starting_balance,
      cash_balance: p.cash_balance,
      is_active: p.is_active,
      holdings: Enum.map(p.holdings, &holding/1),
      inserted_at: p.inserted_at,
      updated_at: p.updated_at
    }
  end

  defp holding(h) do
    %{
      id: h.id,
      ticker: h.ticker,
      quantity: h.quantity,
      average_cost: h.average_cost,
      total_cost: h.total_cost,
      last_updated: h.last_updated
    }
  end
end

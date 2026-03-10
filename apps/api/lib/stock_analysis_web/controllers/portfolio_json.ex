defmodule StockAnalysisWeb.PortfolioJSON do
  alias StockAnalysis.PaperTrading.Portfolio

  def index(%{portfolios: portfolios}) do
    %{data: Enum.map(portfolios, &portfolio_summary/1)}
  end

  def show(%{portfolio: portfolio}) do
    %{data: portfolio_detail(portfolio)}
  end

  def trade(%{result: %{transaction: tx, portfolio: portfolio}}) do
    %{
      data: %{
        transaction: %{
          id: tx.id,
          ticker: tx.ticker,
          side: tx.transaction_type,
          quantity: tx.quantity,
          price_per_share: tx.price_per_share,
          total_amount: tx.total_amount,
          executed_at: tx.executed_at
        },
        portfolio: portfolio_detail(portfolio)
      }
    }
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

  def holdings(%{holdings: enriched_holdings}) do
    %{data: Enum.map(enriched_holdings, &enriched_holding/1)}
  end

  defp enriched_holding(%{holding: h} = eh) do
    %{
      id: h.id,
      ticker: h.ticker,
      quantity: h.quantity,
      average_cost: h.average_cost,
      total_cost: h.total_cost,
      current_price: eh.current_price,
      current_value: eh.current_value,
      gain_loss: eh.gain_loss,
      gain_loss_percent: eh.gain_loss_percent,
      last_updated: h.last_updated
    }
  end

  def transactions(%{result: result}) do
    %{
      data: Enum.map(result.transactions, &transaction_detail_map/1),
      meta: %{
        page: result.page,
        per_page: result.per_page,
        total_count: result.total_count,
        total_pages: result.total_pages
      }
    }
  end

  def transaction_detail(%{transaction: tx}) do
    %{data: transaction_detail_map(tx)}
  end

  defp transaction_detail_map(tx) do
    %{
      id: tx.id,
      ticker: tx.ticker,
      transaction_type: tx.transaction_type,
      quantity: tx.quantity,
      price_per_share: tx.price_per_share,
      total_amount: tx.total_amount,
      recommendation_at_time: tx.recommendation_at_time,
      notes: tx.notes,
      executed_at: tx.executed_at,
      inserted_at: tx.inserted_at
    }
  end

  def performance(%{metrics: m}) do
    %{
      data: %{
        total_value: m.total_value,
        cash_balance: m.cash_balance,
        holdings_value: m.holdings_value,
        total_return: m.total_return,
        realized_gains: m.realized_gains,
        unrealized_gains: m.unrealized_gains,
        best_trade: m.best_trade,
        worst_trade: m.worst_trade,
        win_rate: m.win_rate,
        total_trades: m.total_trades,
        total_sells: m.total_sells,
        profitable_sells: m.profitable_sells,
        most_traded_ticker: m.most_traded_ticker
      }
    }
  end
end

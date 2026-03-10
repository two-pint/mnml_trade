export interface PaperHolding {
  id: string;
  ticker: string;
  quantity: string;
  average_cost: string;
  total_cost: string;
  last_updated: string | null;
}

export interface PaperPortfolio {
  id: string;
  name: string;
  description: string | null;
  starting_balance: string;
  cash_balance: string;
  is_active: boolean;
  holdings_count?: number;
  holdings?: PaperHolding[];
  inserted_at: string;
  updated_at: string;
}

export interface CreatePortfolioRequest {
  name: string;
  description?: string;
  starting_balance?: number;
}

export interface UpdatePortfolioRequest {
  name?: string;
  description?: string;
}

export interface ExecuteTradeRequest {
  ticker: string;
  side: "buy" | "sell";
  quantity: number;
}

export interface PaperTransaction {
  id: string;
  ticker: string;
  side: string;
  quantity: string;
  price_per_share: string;
  total_amount: string;
  executed_at: string;
}

export interface TradeResult {
  transaction: PaperTransaction;
  portfolio: PaperPortfolio;
}

export interface EnrichedHolding {
  id: string;
  ticker: string;
  quantity: string;
  average_cost: string;
  total_cost: string;
  current_price: string;
  current_value: string;
  gain_loss: string;
  gain_loss_percent: string;
  last_updated: string | null;
}

export interface TransactionDetail {
  id: string;
  ticker: string;
  transaction_type: string;
  quantity: string;
  price_per_share: string;
  total_amount: string;
  recommendation_at_time: string | null;
  notes: string | null;
  executed_at: string;
  inserted_at: string;
}

export interface PaginationMeta {
  page: number;
  per_page: number;
  total_count: number;
  total_pages: number;
}

export interface TransactionListParams {
  page?: number;
  per_page?: number;
  ticker?: string;
  type?: "buy" | "sell";
  from?: string;
  to?: string;
}

export interface TradeMetric {
  id: string;
  ticker: string;
  quantity: string;
  price_per_share: string;
  gain: string;
  gain_percent: string;
  executed_at: string;
}

export interface PortfolioPerformance {
  total_value: string;
  cash_balance: string;
  holdings_value: string;
  total_return: string;
  realized_gains: string;
  unrealized_gains: string;
  best_trade: TradeMetric | null;
  worst_trade: TradeMetric | null;
  win_rate: string;
  total_trades: number;
  total_sells: number;
  profitable_sells: number;
  most_traded_ticker: string | null;
}

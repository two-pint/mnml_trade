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

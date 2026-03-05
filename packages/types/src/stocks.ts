export interface SearchResult {
  ticker: string;
  name: string;
  type: string;
  region: string;
}

export interface StockOverview {
  ticker: string;
  symbol: string;
  price: number | null;
  change: number | null;
  change_percent: string | null;
  volume: number | null;
  open: number | null;
  high: number | null;
  low: number | null;
  previous_close: number | null;
  latest_trading_day: string | null;
}

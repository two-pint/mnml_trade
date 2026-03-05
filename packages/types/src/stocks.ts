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

export type TechnicalSignal = "bullish" | "bearish" | "neutral";

export interface IndicatorValue {
  date: string;
  value: number | number[];
}

export interface TechnicalAnalysis {
  ticker: string;
  indicators: Record<string, IndicatorValue | null>;
  score: number;
  signal: TechnicalSignal;
  trend_direction: TechnicalSignal;
  support_resistance: {
    support: number;
    resistance: number;
  };
}

export interface OptionsFlowTrade {
  type: string | null;
  strike: number | null;
  expiry: string | null;
  premium: number | null;
  quantity: number | null;
  sentiment: string | null;
}

export interface DarkPoolSummary {
  volume: number | null;
  net_buy_sell: number | null;
  block_trades: unknown[];
}

export interface InstitutionalData {
  ticker: string;
  options_flow: OptionsFlowTrade[];
  dark_pool: DarkPoolSummary;
  data_as_of: string;
  stale: boolean;
}

export interface DailyOhlcv {
  date: string;
  open: number | null;
  high: number | null;
  low: number | null;
  close: number | null;
  volume: number | null;
}

export type DailySeries = DailyOhlcv[];

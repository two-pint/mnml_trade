export interface SearchResult {
  ticker: string;
  name: string;
  type: string;
  region: string;
}

export type RecommendationLabel =
  | "Strong Buy"
  | "Buy"
  | "Hold"
  | "Sell"
  | "Strong Sell";

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
  recommendation?: RecommendationLabel;
  recommendation_score?: number;
  confidence?: number;
  sub_scores?: {
    technical: number | null;
    fundamental: number | null;
    sentiment: number | null;
    institutional: number | null;
  };
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

export interface CongressionalTrade {
  representative: string | null;
  transaction_type: string | null;
  amount: string | null;
  date: string | null;
  party: string | null;
  ticker: string | null;
}

export interface InsiderTrade {
  insider_name: string | null;
  title: string | null;
  transaction_type: string | null;
  shares: number | null;
  price: number | null;
  value: number | null;
  date: string | null;
}

export interface InstitutionalHolding {
  holder: string | null;
  shares: number | null;
  value: number | null;
  change: number | null;
  change_percent: number | null;
  date: string | null;
}

export interface MarketTide {
  score: number | null;
  label: string | null;
  call_volume: number | null;
  put_volume: number | null;
  ratio: number | null;
}

export type SmartMoneyLabel =
  | "Strong Institutional Buy"
  | "Institutional Buy"
  | "Neutral"
  | "Institutional Sell"
  | "Strong Institutional Sell";

export interface SmartMoneyScore {
  ticker: string;
  score: number;
  label: SmartMoneyLabel;
}

export interface FullInstitutionalData {
  ticker: string;
  options_flow: OptionsFlowTrade[];
  dark_pool: DarkPoolSummary;
  congressional: CongressionalTrade[] | null;
  insider: InsiderTrade[] | null;
  holdings: InstitutionalHolding[] | null;
  market_tide: MarketTide | null;
  smart_money_score: number;
  smart_money_label: SmartMoneyLabel;
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

export interface IntradayOhlcv {
  datetime: string;
  open: number | null;
  high: number | null;
  low: number | null;
  close: number | null;
  volume: number | null;
}

export type IntradaySeries = IntradayOhlcv[];

export interface TrendingStock {
  ticker: string;
  name: string;
  price: number | null;
  change: number | null;
  change_percent: string | null;
}

export type ValueAssessment = "Undervalued" | "Fairly Valued" | "Overvalued";
export type GrowthRating = "Strong" | "Average" | "Weak";
export type HealthRating = "Healthy" | "Average" | "Weak";

export interface CompanyProfile {
  symbol: string;
  company_name: string | null;
  description: string | null;
  sector: string | null;
  industry: string | null;
  market_cap: number | null;
  employees: number | null;
  ceo: string | null;
  city: string | null;
  state: string | null;
  country: string | null;
  website: string | null;
  exchange: string | null;
  currency: string | null;
  price: number | null;
  beta: number | null;
  vol_avg: number | null;
  last_dividend: number | null;
  range: string | null;
  ipo_date: string | null;
  image: string | null;
}

export interface FinancialRatios {
  pe_ratio: number | null;
  pb_ratio: number | null;
  peg_ratio: number | null;
  ps_ratio: number | null;
  roe: number | null;
  roa: number | null;
  gross_margin: number | null;
  operating_margin: number | null;
  net_margin: number | null;
  current_ratio: number | null;
  quick_ratio: number | null;
  debt_to_equity: number | null;
  interest_coverage: number | null;
  dividend_yield: number | null;
  payout_ratio: number | null;
  date: string | null;
}

export interface IncomeStatement {
  date: string | null;
  period: string | null;
  revenue: number | null;
  cost_of_revenue: number | null;
  gross_profit: number | null;
  operating_income: number | null;
  net_income: number | null;
  ebitda: number | null;
  eps: number | null;
  eps_diluted: number | null;
  operating_expenses: number | null;
  interest_expense: number | null;
}

export interface BalanceSheet {
  date: string | null;
  period: string | null;
  total_assets: number | null;
  total_liabilities: number | null;
  total_equity: number | null;
  total_debt: number | null;
  net_debt: number | null;
  cash_and_equivalents: number | null;
  total_current_assets: number | null;
  total_current_liabilities: number | null;
  goodwill: number | null;
  intangible_assets: number | null;
}

export interface CashFlow {
  date: string | null;
  period: string | null;
  operating_cash_flow: number | null;
  capital_expenditure: number | null;
  free_cash_flow: number | null;
  dividends_paid: number | null;
  net_cash_from_financing: number | null;
  net_cash_from_investing: number | null;
}

export interface FundamentalAnalysis {
  ticker: string;
  profile: CompanyProfile;
  ratios: FinancialRatios;
  income_statement: IncomeStatement[];
  balance_sheet: BalanceSheet[];
  cash_flow: CashFlow[];
  score: number;
  assessment: ValueAssessment;
  growth_rating: GrowthRating;
  health_rating: HealthRating;
}

export type SentimentLabel = "Bullish" | "Bearish" | "Neutral";
export type SentimentItemLabel = "bullish" | "bearish" | "neutral";
export type SentimentTrend = "improving" | "declining" | "stable";

export interface SentimentPost {
  title: string;
  body: string;
  score: number;
  num_comments: number;
  subreddit: string;
  created_utc: number | null;
  url: string | null;
  sentiment: SentimentItemLabel;
  sentiment_confidence: number;
}

export interface SentimentNewsArticle {
  headline: string | null;
  summary: string | null;
  source: string | null;
  datetime: number | null;
  url: string | null;
  sentiment_from_source: string | null;
  sentiment: SentimentItemLabel;
  sentiment_confidence: number;
}

export interface SentimentAnalysis {
  ticker: string;
  score: number;
  label: SentimentLabel;
  trend: SentimentTrend;
  mention_count: number;
  top_posts: SentimentPost[];
  news: SentimentNewsArticle[];
}

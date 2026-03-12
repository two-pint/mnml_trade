export interface PriceSnapshot {
  date: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

export interface ScoreSnapshot {
  date: string;
  technical_score: number | null;
  fundamental_score: number | null;
  sentiment_score: number | null;
  smart_money_score: number | null;
  recommendation_score: number | null;
  recommendation_label: string | null;
  confidence: number | null;
}

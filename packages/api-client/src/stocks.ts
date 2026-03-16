import type {
  AgentAnalysis,
  SearchResult,
  StockOverview,
  TechnicalAnalysis,
  FundamentalAnalysis,
  SentimentAnalysis,
  InstitutionalData,
  FullInstitutionalData,
  CongressionalTrade,
  InsiderTrade,
  InstitutionalHolding,
  MarketTide,
  SmartMoneyScore,
  DailySeries,
  IntradaySeries,
  TrendingStock,
  MarketNewsArticle,
  PriceSnapshot,
  ScoreSnapshot,
} from "@repo/types";
import type { ApiClient } from "./client";

export function createStocksApi(client: ApiClient) {
  return {
    searchStocks(q: string): Promise<SearchResult[]> {
      const params = new URLSearchParams({ q: q.trim() });
      return client.get<SearchResult[]>(`/api/stocks/search?${params}`);
    },

    getStock(ticker: string): Promise<StockOverview> {
      const encoded = encodeURIComponent(ticker.trim());
      return client.get<StockOverview>(`/api/stocks/${encoded}`);
    },

    getAgentAnalysis(ticker: string): Promise<AgentAnalysis> {
      const encoded = encodeURIComponent(ticker.trim());
      return client.get<AgentAnalysis>(`/api/stocks/${encoded}/agent-analysis`);
    },

    getStockTechnical(ticker: string): Promise<TechnicalAnalysis> {
      const encoded = encodeURIComponent(ticker.trim());
      return client.get<TechnicalAnalysis>(`/api/stocks/${encoded}/technical`);
    },

    getStockFundamental(ticker: string): Promise<FundamentalAnalysis> {
      const encoded = encodeURIComponent(ticker.trim());
      return client.get<FundamentalAnalysis>(`/api/stocks/${encoded}/fundamental`);
    },

    getStockSentiment(ticker: string): Promise<SentimentAnalysis> {
      const encoded = encodeURIComponent(ticker.trim());
      return client.get<SentimentAnalysis>(`/api/stocks/${encoded}/sentiment`);
    },

    getStockInstitutional(ticker: string): Promise<InstitutionalData> {
      const encoded = encodeURIComponent(ticker.trim());
      return client.get<InstitutionalData>(`/api/stocks/${encoded}/institutional`);
    },

    getStockDaily(ticker: string): Promise<DailySeries> {
      const encoded = encodeURIComponent(ticker.trim());
      return client.get<DailySeries>(`/api/stocks/${encoded}/daily`);
    },

    getStockIntraday(
      ticker: string,
      options?: { interval?: "1min" | "5min" | "1h"; days?: number },
    ): Promise<IntradaySeries> {
      const encoded = encodeURIComponent(ticker.trim());
      const params = new URLSearchParams();
      if (options?.interval) params.set("interval", options.interval);
      if (options?.days != null) params.set("days", String(options.days));
      const qs = params.toString();
      return client.get<IntradaySeries>(`/api/stocks/${encoded}/intraday${qs ? `?${qs}` : ""}`);
    },

    getTrending(): Promise<TrendingStock[]> {
      return client.get<TrendingStock[]>("/api/stocks/trending");
    },

    getCongressional(ticker: string): Promise<{ ticker: string; trades: CongressionalTrade[]; data_as_of: string }> {
      const encoded = encodeURIComponent(ticker.trim());
      return client.get(`/api/institutional/${encoded}/congressional`);
    },

    getInsiderTrades(ticker: string): Promise<{ ticker: string; trades: InsiderTrade[]; data_as_of: string }> {
      const encoded = encodeURIComponent(ticker.trim());
      return client.get(`/api/institutional/${encoded}/insider-trades`);
    },

    getHoldings(ticker: string): Promise<{ ticker: string; holdings: InstitutionalHolding[]; data_as_of: string }> {
      const encoded = encodeURIComponent(ticker.trim());
      return client.get(`/api/institutional/${encoded}/holdings`);
    },

    getMarketTide(): Promise<MarketTide> {
      return client.get<MarketTide>("/api/institutional/market-tide");
    },

    getSmartMoneyScore(ticker: string): Promise<SmartMoneyScore> {
      const encoded = encodeURIComponent(ticker.trim());
      return client.get<SmartMoneyScore>(`/api/institutional/${encoded}/smart-money-score`);
    },

    getPriceHistory(ticker: string, days?: number): Promise<PriceSnapshot[]> {
      const encoded = encodeURIComponent(ticker.trim());
      const params = days != null ? `?days=${days}` : "";
      return client.get<PriceSnapshot[]>(`/api/stocks/${encoded}/price-history${params}`);
    },

    getScoreHistory(ticker: string, days?: number): Promise<ScoreSnapshot[]> {
      const encoded = encodeURIComponent(ticker.trim());
      const params = days != null ? `?days=${days}` : "";
      return client.get<ScoreSnapshot[]>(`/api/stocks/${encoded}/score-history${params}`);
    },

    getMarketNews(): Promise<MarketNewsArticle[]> {
      return client.get<MarketNewsArticle[]>("/api/news/market");
    },
  };
}

export type StocksApi = ReturnType<typeof createStocksApi>;

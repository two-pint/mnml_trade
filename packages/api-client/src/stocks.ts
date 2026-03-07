import type {
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
  TrendingStock,
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
  };
}

export type StocksApi = ReturnType<typeof createStocksApi>;

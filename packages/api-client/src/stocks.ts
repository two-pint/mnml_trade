import type {
  SearchResult,
  StockOverview,
  TechnicalAnalysis,
  InstitutionalData,
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
  };
}

export type StocksApi = ReturnType<typeof createStocksApi>;

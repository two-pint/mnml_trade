import type { SearchResult, StockOverview } from "@repo/types";
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
  };
}

export type StocksApi = ReturnType<typeof createStocksApi>;

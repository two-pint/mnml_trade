import type { WatchlistItem, HistoryEntry } from "@repo/types";
import type { ApiClient } from "./client";

interface DataResponse<T> {
  data: T;
}

export function createEngagementApi(client: ApiClient) {
  return {
    listWatchlist(): Promise<DataResponse<WatchlistItem[]>> {
      return client.get<DataResponse<WatchlistItem[]>>("/api/user/watchlist");
    },

    addToWatchlist(ticker: string): Promise<DataResponse<WatchlistItem>> {
      return client.post<DataResponse<WatchlistItem>>("/api/user/watchlist", { ticker });
    },

    removeFromWatchlist(ticker: string): Promise<void> {
      return client.delete<void>(`/api/user/watchlist/${encodeURIComponent(ticker)}`);
    },

    listHistory(): Promise<DataResponse<HistoryEntry[]>> {
      return client.get<DataResponse<HistoryEntry[]>>("/api/user/history");
    },
  };
}

export type EngagementApi = ReturnType<typeof createEngagementApi>;

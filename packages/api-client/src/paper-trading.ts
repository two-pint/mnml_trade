import type {
  PaperPortfolio,
  CreatePortfolioRequest,
  UpdatePortfolioRequest,
} from "@repo/types";
import type { ApiClient } from "./client";

interface DataResponse<T> {
  data: T;
}

export function createPaperTradingApi(client: ApiClient) {
  return {
    listPortfolios(): Promise<DataResponse<PaperPortfolio[]>> {
      return client.get<DataResponse<PaperPortfolio[]>>("/api/paper-trading/portfolios");
    },

    createPortfolio(payload: CreatePortfolioRequest): Promise<DataResponse<PaperPortfolio>> {
      return client.post<DataResponse<PaperPortfolio>>("/api/paper-trading/portfolios", payload);
    },

    getPortfolio(id: string): Promise<DataResponse<PaperPortfolio>> {
      return client.get<DataResponse<PaperPortfolio>>(`/api/paper-trading/portfolios/${id}`);
    },

    updatePortfolio(id: string, payload: UpdatePortfolioRequest): Promise<DataResponse<PaperPortfolio>> {
      return client.put<DataResponse<PaperPortfolio>>(`/api/paper-trading/portfolios/${id}`, payload);
    },

    deletePortfolio(id: string): Promise<void> {
      return client.delete<void>(`/api/paper-trading/portfolios/${id}`);
    },
  };
}

export type PaperTradingApi = ReturnType<typeof createPaperTradingApi>;

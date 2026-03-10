import type {
  PaperPortfolio,
  CreatePortfolioRequest,
  UpdatePortfolioRequest,
  ExecuteTradeRequest,
  TradeResult,
  EnrichedHolding,
  TransactionDetail,
  TransactionListParams,
  PortfolioPerformance,
  PaginationMeta,
} from "@repo/types";
import type { ApiClient } from "./client";

interface DataResponse<T> {
  data: T;
}

interface PaginatedResponse<T> {
  data: T;
  meta: PaginationMeta;
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

    executeTrade(portfolioId: string, payload: ExecuteTradeRequest): Promise<DataResponse<TradeResult>> {
      return client.post<DataResponse<TradeResult>>(
        `/api/paper-trading/portfolios/${portfolioId}/trade`,
        payload,
      );
    },

    listHoldings(portfolioId: string): Promise<DataResponse<EnrichedHolding[]>> {
      return client.get<DataResponse<EnrichedHolding[]>>(
        `/api/paper-trading/portfolios/${portfolioId}/holdings`,
      );
    },

    listTransactions(
      portfolioId: string,
      params?: TransactionListParams,
    ): Promise<PaginatedResponse<TransactionDetail[]>> {
      const searchParams = new URLSearchParams();
      if (params?.page) searchParams.set("page", String(params.page));
      if (params?.per_page) searchParams.set("per_page", String(params.per_page));
      if (params?.ticker) searchParams.set("ticker", params.ticker);
      if (params?.type) searchParams.set("type", params.type);
      if (params?.from) searchParams.set("from", params.from);
      if (params?.to) searchParams.set("to", params.to);
      const qs = searchParams.toString();
      const url = `/api/paper-trading/portfolios/${portfolioId}/transactions${qs ? `?${qs}` : ""}`;
      return client.get<PaginatedResponse<TransactionDetail[]>>(url);
    },

    getTransaction(portfolioId: string, transactionId: string): Promise<DataResponse<TransactionDetail>> {
      return client.get<DataResponse<TransactionDetail>>(
        `/api/paper-trading/portfolios/${portfolioId}/transactions/${transactionId}`,
      );
    },

    getPerformance(portfolioId: string): Promise<DataResponse<PortfolioPerformance>> {
      return client.get<DataResponse<PortfolioPerformance>>(
        `/api/paper-trading/portfolios/${portfolioId}/performance`,
      );
    },
  };
}

export type PaperTradingApi = ReturnType<typeof createPaperTradingApi>;

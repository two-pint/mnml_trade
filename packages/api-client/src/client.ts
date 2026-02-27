import type { ApiError } from "@repo/types";
import { ApiClientError } from "./error";

export interface ApiClientConfig {
  baseUrl: string;
  getToken?: () => string | null;
}

type RequestOptions = Omit<RequestInit, "body"> & {
  body?: unknown;
};

export class ApiClient {
  private baseUrl: string;
  private getToken: () => string | null;

  constructor(config: ApiClientConfig) {
    this.baseUrl = config.baseUrl.replace(/\/+$/, "");
    this.getToken = config.getToken ?? (() => null);
  }

  async get<T>(path: string, options?: RequestOptions): Promise<T> {
    return this.request<T>(path, { ...options, method: "GET" });
  }

  async post<T>(path: string, body?: unknown, options?: RequestOptions): Promise<T> {
    return this.request<T>(path, { ...options, method: "POST", body });
  }

  async put<T>(path: string, body?: unknown, options?: RequestOptions): Promise<T> {
    return this.request<T>(path, { ...options, method: "PUT", body });
  }

  async delete<T>(path: string, options?: RequestOptions): Promise<T> {
    return this.request<T>(path, { ...options, method: "DELETE" });
  }

  private async request<T>(path: string, options: RequestOptions = {}): Promise<T> {
    const { body, headers: extraHeaders, ...rest } = options;
    const token = this.getToken();

    const headers: Record<string, string> = {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...(extraHeaders as Record<string, string>),
    };

    if (token) {
      headers["Authorization"] = `Bearer ${token}`;
    }

    const response = await fetch(`${this.baseUrl}${path}`, {
      ...rest,
      headers,
      body: body != null ? JSON.stringify(body) : undefined,
    });

    if (!response.ok) {
      let error: ApiError;
      try {
        error = (await response.json()) as ApiError;
      } catch {
        error = { error: "unknown", message: response.statusText };
      }
      throw new ApiClientError(response.status, error);
    }

    if (response.status === 204) {
      return undefined as T;
    }

    return response.json() as Promise<T>;
  }
}

import { ApiClient, createAuthApi, createStocksApi, createPaperTradingApi, createEngagementApi } from "@repo/api-client";

let token: string | null = null;

function setCookie(name: string, value: string, days = 7) {
  const expires = new Date(Date.now() + days * 864e5).toUTCString();
  document.cookie = `${name}=${encodeURIComponent(value)};expires=${expires};path=/;SameSite=Lax`;
}

function deleteCookie(name: string) {
  document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/`;
}

export function setToken(t: string | null) {
  token = t;
  if (t) {
    localStorage.setItem("token", t);
    setCookie("token", t);
  } else {
    localStorage.removeItem("token");
    deleteCookie("token");
  }
}

export function getToken(): string | null {
  if (token) return token;
  if (typeof window !== "undefined") {
    token = localStorage.getItem("token");
  }
  return token;
}

export function setRefreshToken(t: string | null) {
  if (t) {
    localStorage.setItem("refresh_token", t);
  } else {
    localStorage.removeItem("refresh_token");
  }
}

export function clearTokens() {
  token = null;
  localStorage.removeItem("token");
  localStorage.removeItem("refresh_token");
  deleteCookie("token");
}

const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:4000";

export const apiClient = new ApiClient({
  baseUrl: apiUrl,
  getToken,
});

export const authApi = createAuthApi(apiClient);
export const stocksApi = createStocksApi(apiClient);
export const paperTradingApi = createPaperTradingApi(apiClient);
export const engagementApi = createEngagementApi(apiClient);

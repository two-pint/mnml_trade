import * as SecureStore from "expo-secure-store";
import { ApiClient, createAuthApi, createStocksApi, createPaperTradingApi, createEngagementApi } from "@repo/api-client";

const TOKEN_KEY = "auth_token";
const REFRESH_TOKEN_KEY = "refresh_token";

let cachedToken: string | null = null;

export async function setToken(t: string | null): Promise<void> {
  cachedToken = t;
  if (t) {
    await SecureStore.setItemAsync(TOKEN_KEY, t);
  } else {
    await SecureStore.deleteItemAsync(TOKEN_KEY);
  }
}

export function getToken(): string | null {
  return cachedToken;
}

export async function loadToken(): Promise<string | null> {
  cachedToken = await SecureStore.getItemAsync(TOKEN_KEY);
  return cachedToken;
}

export async function getRefreshToken(): Promise<string | null> {
  return SecureStore.getItemAsync(REFRESH_TOKEN_KEY);
}

export async function setRefreshToken(t: string | null): Promise<void> {
  if (t) {
    await SecureStore.setItemAsync(REFRESH_TOKEN_KEY, t);
  } else {
    await SecureStore.deleteItemAsync(REFRESH_TOKEN_KEY);
  }
}

export async function clearTokens(): Promise<void> {
  cachedToken = null;
  await SecureStore.deleteItemAsync(TOKEN_KEY);
  await SecureStore.deleteItemAsync(REFRESH_TOKEN_KEY);
}

const apiUrl = process.env.EXPO_PUBLIC_API_URL ?? "http://localhost:4000";

export const apiClient = new ApiClient({
  baseUrl: apiUrl,
  getToken,
});

export const authApi = createAuthApi(apiClient);
export const stocksApi = createStocksApi(apiClient);
export const paperTradingApi = createPaperTradingApi(apiClient);
export const engagementApi = createEngagementApi(apiClient);

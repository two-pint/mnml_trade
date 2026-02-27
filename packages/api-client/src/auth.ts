import type {
  LoginRequest,
  RegisterRequest,
  AuthResponse,
  RefreshResponse,
  ForgotPasswordRequest,
  ResetPasswordRequest,
} from "@repo/types";
import type { ApiClient } from "./client";

export function createAuthApi(client: ApiClient) {
  return {
    login(email: string, password: string): Promise<AuthResponse> {
      const body: LoginRequest = { email, password };
      return client.post<AuthResponse>("/api/auth/login", body);
    },

    register(payload: RegisterRequest): Promise<AuthResponse> {
      return client.post<AuthResponse>("/api/auth/register", payload);
    },

    refresh(refreshToken: string): Promise<RefreshResponse> {
      return client.post<RefreshResponse>("/api/auth/refresh", {
        refresh_token: refreshToken,
      });
    },

    forgotPassword(email: string): Promise<void> {
      const body: ForgotPasswordRequest = { email };
      return client.post<void>("/api/auth/forgot-password", body);
    },

    resetPassword(token: string, password: string): Promise<void> {
      const body: ResetPasswordRequest = { token, password };
      return client.post<void>("/api/auth/reset-password", body);
    },

    logout(): Promise<void> {
      return client.post<void>("/api/auth/logout");
    },
  };
}

export type AuthApi = ReturnType<typeof createAuthApi>;

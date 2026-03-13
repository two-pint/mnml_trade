import type {
  User,
  PushTokenRequest,
  PushTokenResponse,
  NotificationPreferences,
  LLMSettings,
  LLMSettingsUpdate,
} from "@repo/types";
import type { ApiClient } from "./client";

interface DataResponse<T> {
  data: T;
}

export function createUserApi(client: ApiClient) {
  return {
    getMe(): Promise<User> {
      return client.get<User>("/api/user/me");
    },

    updateProfile(params: { username?: string }): Promise<User> {
      return client.put<User>("/api/user/profile", params);
    },

    registerPushToken(params: PushTokenRequest): Promise<DataResponse<PushTokenResponse>> {
      return client.post<DataResponse<PushTokenResponse>>("/api/user/push-token", params);
    },

    removePushToken(token: string): Promise<void> {
      return client.delete<void>("/api/user/push-token", { body: { token } });
    },

    getNotificationPreferences(): Promise<DataResponse<NotificationPreferences>> {
      return client.get<DataResponse<NotificationPreferences>>(
        "/api/user/notification-preferences",
      );
    },

    updateNotificationPreferences(
      prefs: Partial<NotificationPreferences>,
    ): Promise<DataResponse<NotificationPreferences>> {
      return client.put<DataResponse<NotificationPreferences>>(
        "/api/user/notification-preferences",
        prefs,
      );
    },

    getLLMSettings(): Promise<DataResponse<LLMSettings>> {
      return client.get<DataResponse<LLMSettings>>("/api/user/llm-settings");
    },

    updateLLMSettings(settings: LLMSettingsUpdate): Promise<DataResponse<LLMSettings>> {
      return client.put<DataResponse<LLMSettings>>("/api/user/llm-settings", settings);
    },
  };
}

export type UserApi = ReturnType<typeof createUserApi>;

export interface PushTokenRequest {
  token: string;
  platform: "ios" | "android" | "web";
}

export interface PushTokenResponse {
  id: string;
  token: string;
  platform: string;
}

export interface NotificationPreferences {
  push_enabled: boolean;
  price_alerts: boolean;
  whale_alerts: boolean;
}

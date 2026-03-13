export type LLMProvider = "openai" | "anthropic";

export interface LLMSettings {
  provider: LLMProvider | null;
  model: string | null;
  api_key_configured: boolean;
}

export interface LLMSettingsUpdate {
  provider: LLMProvider;
  api_key?: string;
  model?: string;
}

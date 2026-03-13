"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { userApi } from "@/lib/api";
import type { NotificationPreferences, LLMSettings, LLMProvider } from "@repo/types";

export default function ProfilePage() {
  const { user, logout } = useAuth();
  const router = useRouter();

  const [username, setUsername] = useState(user?.username ?? "");
  const [editingUsername, setEditingUsername] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  const [prefs, setPrefs] = useState<NotificationPreferences | null>(null);
  const [prefsLoading, setPrefsLoading] = useState(true);

  const [llmSettings, setLlmSettings] = useState<LLMSettings | null>(null);
  const [llmLoading, setLlmLoading] = useState(true);
  const [llmProvider, setLlmProvider] = useState<LLMProvider>("openai");
  const [llmApiKey, setLlmApiKey] = useState("");
  const [llmModel, setLlmModel] = useState("");
  const [llmSaving, setLlmSaving] = useState(false);
  const [llmSaveError, setLlmSaveError] = useState<string | null>(null);
  const [llmSaveSuccess, setLlmSaveSuccess] = useState(false);

  const loadPrefs = useCallback(() => {
    userApi
      .getNotificationPreferences()
      .then(({ data }) => setPrefs(data))
      .catch(() => {})
      .finally(() => setPrefsLoading(false));
  }, []);

  const loadLlmSettings = useCallback(() => {
    userApi
      .getLLMSettings()
      .then(({ data }) => {
        setLlmSettings(data);
        setLlmProvider(data.provider ?? "openai");
        setLlmModel(data.model ?? "");
      })
      .catch(() => {})
      .finally(() => setLlmLoading(false));
  }, []);

  useEffect(() => {
    loadPrefs();
  }, [loadPrefs]);

  useEffect(() => {
    loadLlmSettings();
  }, [loadLlmSettings]);

  const handleSaveUsername = async () => {
    setSaving(true);
    setSaveError(null);
    try {
      await userApi.updateProfile({ username });
      setEditingUsername(false);
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 3000);
    } catch {
      setSaveError("Failed to update username");
    } finally {
      setSaving(false);
    }
  };

  const handleSaveLlmSettings = async () => {
    setLlmSaving(true);
    setLlmSaveError(null);
    try {
      const payload: { provider: LLMProvider; api_key?: string; model?: string } = {
        provider: llmProvider,
      };
      if (llmApiKey.trim()) payload.api_key = llmApiKey.trim();
      if (llmModel.trim()) payload.model = llmModel.trim();
      const { data } = await userApi.updateLLMSettings(payload);
      setLlmSettings(data);
      setLlmApiKey("");
      setLlmSaveSuccess(true);
      setTimeout(() => setLlmSaveSuccess(false), 3000);
    } catch (e: unknown) {
      const msg = e && typeof e === "object" && "message" in e ? String((e as { message: unknown }).message) : "Failed to save AI settings";
      setLlmSaveError(msg);
    } finally {
      setLlmSaving(false);
    }
  };

  const togglePref = async (key: keyof NotificationPreferences) => {
    if (!prefs) return;
    const updated = { ...prefs, [key]: !prefs[key] };
    setPrefs(updated);
    try {
      await userApi.updateNotificationPreferences({ [key]: updated[key] });
    } catch {
      setPrefs(prefs);
    }
  };

  const handleLogout = () => {
    logout();
    router.replace("/login");
  };

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
      <h1 className="text-2xl font-bold text-gray-900">Profile</h1>

      {/* User Info */}
      <section className="mt-8 rounded-xl border border-gray-200 bg-white shadow-sm">
        <div className="border-b border-gray-100 px-6 py-5">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-500">Email</p>
          <p className="mt-1 text-gray-900">{user?.email}</p>
        </div>

        <div className="px-6 py-5">
          <div className="flex items-center justify-between">
            <p className="text-xs font-medium uppercase tracking-wide text-gray-500">Username</p>
            {!editingUsername && (
              <button
                type="button"
                onClick={() => setEditingUsername(true)}
                className="text-sm font-medium text-primary-600 hover:underline"
              >
                Edit
              </button>
            )}
          </div>
          {editingUsername ? (
            <div className="mt-2">
              <input
                type="text"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                className="w-full rounded-lg border border-gray-300 bg-gray-50 px-4 py-2.5 text-gray-900 outline-none focus:border-primary-500 focus:ring-1 focus:ring-primary-500"
              />
              {saveError && (
                <p className="mt-1 text-sm text-bearish">{saveError}</p>
              )}
              <div className="mt-3 flex gap-3">
                <button
                  type="button"
                  onClick={handleSaveUsername}
                  disabled={saving}
                  className="rounded-lg bg-primary-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-primary-700 disabled:opacity-50"
                >
                  {saving ? "Saving..." : "Save"}
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setUsername(user?.username ?? "");
                    setEditingUsername(false);
                    setSaveError(null);
                  }}
                  className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 transition-colors hover:bg-gray-50"
                >
                  Cancel
                </button>
              </div>
            </div>
          ) : (
            <div className="mt-1 flex items-center gap-2">
              <p className="text-gray-900">{user?.username ?? "Not set"}</p>
              {saveSuccess && (
                <span className="text-sm text-bullish">Updated</span>
              )}
            </div>
          )}
        </div>
      </section>

      {/* AI analysis (BYOK) */}
      <section className="mt-6 rounded-xl border border-gray-200 bg-white shadow-sm">
        <div className="border-b border-gray-100 px-6 py-4">
          <h2 className="text-sm font-semibold text-gray-700">AI analysis</h2>
          <p className="mt-0.5 text-xs text-gray-500">
            Add your own API key to enable AI-powered stock analysis. Your key is stored securely and never shared.
          </p>
        </div>
        {llmLoading ? (
          <div className="px-6 py-8">
            <div className="h-6 w-48 animate-pulse rounded bg-gray-100" />
          </div>
        ) : (
          <div className="space-y-4 px-6 py-5">
            <div>
              <label className="block text-sm font-medium text-gray-700">Provider</label>
              <select
                value={llmProvider}
                onChange={(e) => setLlmProvider(e.target.value as LLMProvider)}
                className="mt-1 w-full rounded-lg border border-gray-300 bg-gray-50 px-4 py-2.5 text-gray-900 outline-none focus:border-primary-500 focus:ring-1 focus:ring-primary-500"
              >
                <option value="openai">OpenAI (GPT)</option>
                <option value="anthropic">Anthropic (Claude)</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">API key</label>
              <input
                type="password"
                value={llmApiKey}
                onChange={(e) => setLlmApiKey(e.target.value)}
                placeholder={llmSettings?.api_key_configured ? "•••••••• (leave blank to keep current)" : "sk-..."}
                className="mt-1 w-full rounded-lg border border-gray-300 bg-gray-50 px-4 py-2.5 text-gray-900 outline-none focus:border-primary-500 focus:ring-1 focus:ring-primary-500"
              />
              {llmSettings?.api_key_configured && (
                <p className="mt-1 text-xs text-gray-500">API key configured</p>
              )}
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Model (optional)</label>
              <input
                type="text"
                value={llmModel}
                onChange={(e) => setLlmModel(e.target.value)}
                placeholder={llmProvider === "openai" ? "e.g. gpt-4o" : "e.g. claude-3-5-sonnet"}
                className="mt-1 w-full rounded-lg border border-gray-300 bg-gray-50 px-4 py-2.5 text-gray-900 outline-none focus:border-primary-500 focus:ring-1 focus:ring-primary-500"
              />
            </div>
            {llmSaveError && (
              <p className="text-sm text-bearish">{llmSaveError}</p>
            )}
            <button
              type="button"
              onClick={handleSaveLlmSettings}
              disabled={llmSaving || (!llmApiKey.trim() && !llmSettings?.api_key_configured)}
              className="rounded-lg bg-primary-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-primary-700 disabled:opacity-50"
            >
              {llmSaving ? "Saving..." : "Save AI settings"}
            </button>
            {llmSaveSuccess && (
              <span className="ml-2 text-sm text-bullish">Saved</span>
            )}
          </div>
        )}
      </section>

      {/* Notification Preferences */}
      <section className="mt-6 rounded-xl border border-gray-200 bg-white shadow-sm">
        <div className="border-b border-gray-100 px-6 py-4">
          <h2 className="text-sm font-semibold text-gray-700">Notification Preferences</h2>
        </div>
        {prefsLoading ? (
          <div className="px-6 py-8">
            <div className="h-6 w-48 animate-pulse rounded bg-gray-100" />
          </div>
        ) : prefs ? (
          <div className="divide-y divide-gray-50">
            <ToggleRow
              label="Push Notifications"
              description="Enable all push notifications (mobile)"
              checked={prefs.push_enabled}
              onChange={() => togglePref("push_enabled")}
            />
            <ToggleRow
              label="Price Alerts"
              description="Get notified on large price movements for watchlist stocks"
              checked={prefs.price_alerts}
              onChange={() => togglePref("price_alerts")}
              disabled={!prefs.push_enabled}
            />
            <ToggleRow
              label="Whale Alerts"
              description="Unusual options activity notifications"
              checked={prefs.whale_alerts}
              onChange={() => togglePref("whale_alerts")}
              disabled={!prefs.push_enabled}
            />
          </div>
        ) : null}
      </section>

      {/* Logout */}
      <section className="mt-6">
        <button
          type="button"
          onClick={handleLogout}
          className="w-full rounded-xl border border-red-200 bg-red-50 py-3 text-center font-semibold text-red-600 transition-colors hover:bg-red-100"
        >
          Sign Out
        </button>
      </section>
    </div>
  );
}

function ToggleRow({
  label,
  description,
  checked,
  onChange,
  disabled,
}: {
  label: string;
  description: string;
  checked: boolean;
  onChange: () => void;
  disabled?: boolean;
}) {
  return (
    <div className="flex items-center justify-between px-6 py-4">
      <div>
        <p className={`text-sm font-medium ${disabled ? "text-gray-400" : "text-gray-900"}`}>
          {label}
        </p>
        <p className="text-sm text-gray-500">{description}</p>
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        onClick={onChange}
        disabled={disabled}
        className={`relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 ${
          checked ? "bg-primary-600" : "bg-gray-200"
        }`}
      >
        <span
          className={`pointer-events-none inline-block h-5 w-5 rounded-full bg-white shadow ring-0 transition duration-200 ${
            checked ? "translate-x-5" : "translate-x-0"
          }`}
        />
      </button>
    </div>
  );
}

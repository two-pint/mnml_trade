"use client";

import { useCallback, useEffect, useState } from "react";
import {
  View,
  Text,
  TouchableOpacity,
  Switch,
  TextInput,
  ActivityIndicator,
  Alert,
  ScrollView,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useAuth } from "@/lib/auth-context";
import { userApi } from "@/lib/api";
import type { NotificationPreferences, LLMSettings, LLMProvider } from "@repo/types";

export default function ProfileTab() {
  const { user, logout } = useAuth();
  const [username, setUsername] = useState(user?.username ?? "");
  const [editingUsername, setEditingUsername] = useState(false);
  const [saving, setSaving] = useState(false);
  const [prefs, setPrefs] = useState<NotificationPreferences | null>(null);
  const [prefsLoading, setPrefsLoading] = useState(true);

  const [llmSettings, setLlmSettings] = useState<LLMSettings | null>(null);
  const [llmLoading, setLlmLoading] = useState(true);
  const [llmProvider, setLlmProvider] = useState<LLMProvider>("openai");
  const [llmApiKey, setLlmApiKey] = useState("");
  const [llmModel, setLlmModel] = useState("");
  const [llmSaving, setLlmSaving] = useState(false);

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
    try {
      await userApi.updateProfile({ username });
      setEditingUsername(false);
    } catch {
      Alert.alert("Error", "Failed to update username");
    } finally {
      setSaving(false);
    }
  };

  const handleSaveLlmSettings = async () => {
    setLlmSaving(true);
    try {
      const payload: { provider: LLMProvider; api_key?: string; model?: string } = {
        provider: llmProvider,
      };
      if (llmApiKey.trim()) payload.api_key = llmApiKey.trim();
      if (llmModel.trim()) payload.model = llmModel.trim();
      const { data } = await userApi.updateLLMSettings(payload);
      setLlmSettings(data);
      setLlmApiKey("");
    } catch {
      Alert.alert("Error", "Failed to save AI settings");
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

  return (
    <SafeAreaView className="flex-1 bg-white" edges={["top"]}>
      <ScrollView className="flex-1">
        <View className="border-b border-gray-200 px-4 py-4">
          <Text className="text-2xl font-bold text-gray-900">Profile</Text>
        </View>

        {/* User Info */}
        <View className="border-b border-gray-100 px-4 py-5">
          <Text className="mb-1 text-xs font-medium uppercase tracking-wide text-gray-500">
            Email
          </Text>
          <Text className="text-base text-gray-900">{user?.email}</Text>
        </View>

        <View className="border-b border-gray-100 px-4 py-5">
          <View className="flex-row items-center justify-between">
            <Text className="text-xs font-medium uppercase tracking-wide text-gray-500">
              Username
            </Text>
            {!editingUsername && (
              <TouchableOpacity onPress={() => setEditingUsername(true)}>
                <Text className="text-sm font-medium text-primary-600">Edit</Text>
              </TouchableOpacity>
            )}
          </View>
          {editingUsername ? (
            <View className="mt-2">
              <TextInput
                value={username}
                onChangeText={setUsername}
                autoCapitalize="none"
                autoCorrect={false}
                className="rounded-lg border border-gray-300 bg-gray-50 px-4 py-3 text-base text-gray-900"
              />
              <View className="mt-3 flex-row gap-3">
                <TouchableOpacity
                  onPress={handleSaveUsername}
                  disabled={saving}
                  className="rounded-lg bg-primary-600 px-4 py-2"
                  style={{ opacity: saving ? 0.5 : 1 }}
                >
                  <Text className="font-medium text-white">
                    {saving ? "Saving..." : "Save"}
                  </Text>
                </TouchableOpacity>
                <TouchableOpacity
                  onPress={() => {
                    setUsername(user?.username ?? "");
                    setEditingUsername(false);
                  }}
                  className="rounded-lg bg-gray-200 px-4 py-2"
                >
                  <Text className="font-medium text-gray-700">Cancel</Text>
                </TouchableOpacity>
              </View>
            </View>
          ) : (
            <Text className="mt-1 text-base text-gray-900">
              {user?.username ?? "Not set"}
            </Text>
          )}
        </View>

        {/* AI analysis (BYOK) */}
        <View className="border-t border-gray-100 px-4 py-5">
          <Text className="mb-1 text-xs font-medium uppercase tracking-wide text-gray-500">
            AI analysis
          </Text>
          <Text className="mb-4 text-sm text-gray-500">
            Add your API key to enable AI stock analysis. Stored securely on the server.
          </Text>
          {llmLoading ? (
            <ActivityIndicator size="small" color="#4c6ef5" />
          ) : (
            <View className="gap-4">
              <View>
                <Text className="mb-1 text-sm font-medium text-gray-700">Provider</Text>
                <View className="flex-row gap-3">
                  <TouchableOpacity
                    onPress={() => setLlmProvider("openai")}
                    className={`rounded-lg border px-4 py-2 ${llmProvider === "openai" ? "border-primary-600 bg-primary-50" : "border-gray-200 bg-gray-50"}`}
                  >
                    <Text className={llmProvider === "openai" ? "font-medium text-primary-600" : "text-gray-700"}>
                      OpenAI
                    </Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    onPress={() => setLlmProvider("anthropic")}
                    className={`rounded-lg border px-4 py-2 ${llmProvider === "anthropic" ? "border-primary-600 bg-primary-50" : "border-gray-200 bg-gray-50"}`}
                  >
                    <Text className={llmProvider === "anthropic" ? "font-medium text-primary-600" : "text-gray-700"}>
                      Anthropic
                    </Text>
                  </TouchableOpacity>
                </View>
              </View>
              <View>
                <Text className="mb-1 text-sm font-medium text-gray-700">API key</Text>
                <TextInput
                  value={llmApiKey}
                  onChangeText={setLlmApiKey}
                  placeholder={llmSettings?.api_key_configured ? "Leave blank to keep current" : "sk-..."}
                  secureTextEntry
                  autoCapitalize="none"
                  autoCorrect={false}
                  className="rounded-lg border border-gray-300 bg-gray-50 px-4 py-3 text-base text-gray-900"
                />
                {llmSettings?.api_key_configured && (
                  <Text className="mt-1 text-xs text-gray-500">API key configured</Text>
                )}
              </View>
              <View>
                <Text className="mb-1 text-sm font-medium text-gray-700">Model (optional)</Text>
                <TextInput
                  value={llmModel}
                  onChangeText={setLlmModel}
                  placeholder={llmProvider === "openai" ? "e.g. gpt-4o" : "e.g. claude-3-5-sonnet"}
                  autoCapitalize="none"
                  className="rounded-lg border border-gray-300 bg-gray-50 px-4 py-3 text-base text-gray-900"
                />
              </View>
              <TouchableOpacity
                onPress={handleSaveLlmSettings}
                disabled={llmSaving || (!llmApiKey.trim() && !llmSettings?.api_key_configured)}
                className="rounded-lg bg-primary-600 py-3"
                style={{ opacity: (llmSaving || (!llmApiKey.trim() && !llmSettings?.api_key_configured)) ? 0.5 : 1 }}
              >
                <Text className="text-center font-medium text-white">
                  {llmSaving ? "Saving..." : "Save AI settings"}
                </Text>
              </TouchableOpacity>
            </View>
          )}
        </View>

        {/* Notification Preferences */}
        <View className="px-4 py-5">
          <Text className="mb-4 text-xs font-medium uppercase tracking-wide text-gray-500">
            Notifications
          </Text>
          {prefsLoading ? (
            <ActivityIndicator size="small" color="#4c6ef5" />
          ) : prefs ? (
            <View className="gap-4">
              <View className="flex-row items-center justify-between">
                <View>
                  <Text className="text-base text-gray-900">Push Notifications</Text>
                  <Text className="text-sm text-gray-500">Enable all push notifications</Text>
                </View>
                <Switch
                  value={prefs.push_enabled}
                  onValueChange={() => togglePref("push_enabled")}
                  trackColor={{ true: "#4c6ef5" }}
                />
              </View>
              <View className="flex-row items-center justify-between">
                <View>
                  <Text className="text-base text-gray-900">Price Alerts</Text>
                  <Text className="text-sm text-gray-500">
                    Notify on large price moves
                  </Text>
                </View>
                <Switch
                  value={prefs.price_alerts}
                  onValueChange={() => togglePref("price_alerts")}
                  trackColor={{ true: "#4c6ef5" }}
                  disabled={!prefs.push_enabled}
                />
              </View>
              <View className="flex-row items-center justify-between">
                <View>
                  <Text className="text-base text-gray-900">Whale Alerts</Text>
                  <Text className="text-sm text-gray-500">
                    Unusual options activity alerts
                  </Text>
                </View>
                <Switch
                  value={prefs.whale_alerts}
                  onValueChange={() => togglePref("whale_alerts")}
                  trackColor={{ true: "#4c6ef5" }}
                  disabled={!prefs.push_enabled}
                />
              </View>
            </View>
          ) : null}
        </View>

        {/* Logout */}
        <View className="px-4 py-5">
          <TouchableOpacity
            onPress={() => {
              Alert.alert("Sign Out", "Are you sure?", [
                { text: "Cancel", style: "cancel" },
                { text: "Sign Out", style: "destructive", onPress: () => logout() },
              ]);
            }}
            className="rounded-lg border border-red-200 bg-red-50 py-3"
          >
            <Text className="text-center font-semibold text-red-600">Sign Out</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

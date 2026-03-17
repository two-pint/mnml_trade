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
import { useTheme, type Theme } from "@/lib/theme-context";
import { userApi } from "@/lib/api";
import type { NotificationPreferences } from "@repo/types";

const THEME_ORDER: Theme[] = ["system", "light", "dark"];
const THEME_LABELS: Record<Theme, string> = {
  system: "System",
  light: "Light",
  dark: "Dark",
};

export default function ProfileTab() {
  const { user, logout } = useAuth();
  const { theme, setTheme } = useTheme();
  const [username, setUsername] = useState(user?.username ?? "");
  const [editingUsername, setEditingUsername] = useState(false);
  const [saving, setSaving] = useState(false);
  const [prefs, setPrefs] = useState<NotificationPreferences | null>(null);
  const [prefsLoading, setPrefsLoading] = useState(true);

  const loadPrefs = useCallback(() => {
    userApi
      .getNotificationPreferences()
      .then(({ data }) => setPrefs(data))
      .catch(() => {})
      .finally(() => setPrefsLoading(false));
  }, []);

  useEffect(() => {
    loadPrefs();
  }, [loadPrefs]);

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

  const cycleTheme = () => {
    const idx = THEME_ORDER.indexOf(theme);
    setTheme(THEME_ORDER[(idx + 1) % THEME_ORDER.length]);
  };

  return (
    <SafeAreaView className="flex-1 bg-white dark:bg-zinc-900" edges={["top"]}>
      <ScrollView className="flex-1">
        <View className="border-b border-zinc-200 px-4 py-4 dark:border-zinc-700">
          <Text className="text-2xl font-bold text-zinc-900 dark:text-zinc-100">Profile</Text>
        </View>

        {/* Appearance */}
        <View className="border-b border-zinc-100 px-4 py-5 dark:border-zinc-800">
          <Text className="mb-1 text-xs font-medium uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
            Appearance
          </Text>
          <TouchableOpacity
            onPress={cycleTheme}
            className="mt-2 flex-row items-center justify-between rounded-lg border border-zinc-200 bg-zinc-50 px-4 py-3 dark:border-zinc-700 dark:bg-zinc-800"
          >
            <Text className="text-base text-zinc-900 dark:text-zinc-100">Theme</Text>
            <Text className="text-sm text-zinc-500 dark:text-zinc-400">{THEME_LABELS[theme]}</Text>
          </TouchableOpacity>
        </View>

        {/* User Info */}
        <View className="border-b border-zinc-100 px-4 py-5 dark:border-zinc-800">
          <Text className="mb-1 text-xs font-medium uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
            Email
          </Text>
          <Text className="text-base text-zinc-900 dark:text-zinc-100">{user?.email}</Text>
        </View>

        <View className="border-b border-zinc-100 px-4 py-5 dark:border-zinc-800">
          <View className="flex-row items-center justify-between">
            <Text className="text-xs font-medium uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
              Username
            </Text>
            {!editingUsername && (
              <TouchableOpacity onPress={() => setEditingUsername(true)}>
                <Text className="text-sm font-medium text-primary-600 dark:text-primary-400">Edit</Text>
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
                className="rounded-lg border border-zinc-300 bg-zinc-50 px-4 py-3 text-base text-zinc-900 dark:border-zinc-600 dark:bg-zinc-800 dark:text-zinc-100"
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
                  className="rounded-lg bg-zinc-200 px-4 py-2 dark:bg-zinc-700"
                >
                  <Text className="font-medium text-zinc-700 dark:text-zinc-300">Cancel</Text>
                </TouchableOpacity>
              </View>
            </View>
          ) : (
            <Text className="mt-1 text-base text-zinc-900 dark:text-zinc-100">
              {user?.username ?? "Not set"}
            </Text>
          )}
        </View>

        {/* Notification Preferences */}
        <View className="px-4 py-5">
          <Text className="mb-4 text-xs font-medium uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
            Notifications
          </Text>
          {prefsLoading ? (
            <ActivityIndicator size="small" color="#4c6ef5" />
          ) : prefs ? (
            <View className="gap-4">
              <View className="flex-row items-center justify-between">
                <View>
                  <Text className="text-base text-zinc-900 dark:text-zinc-100">Push Notifications</Text>
                  <Text className="text-sm text-zinc-500 dark:text-zinc-400">Enable all push notifications</Text>
                </View>
                <Switch
                  value={prefs.push_enabled}
                  onValueChange={() => togglePref("push_enabled")}
                  trackColor={{ true: "#4c6ef5" }}
                />
              </View>
              <View className="flex-row items-center justify-between">
                <View>
                  <Text className="text-base text-zinc-900 dark:text-zinc-100">Price Alerts</Text>
                  <Text className="text-sm text-zinc-500 dark:text-zinc-400">
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
                  <Text className="text-base text-zinc-900 dark:text-zinc-100">Whale Alerts</Text>
                  <Text className="text-sm text-zinc-500 dark:text-zinc-400">
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
            className="rounded-lg border border-red-200 bg-red-50 py-3 dark:border-red-900 dark:bg-red-950/50"
          >
            <Text className="text-center font-semibold text-red-600 dark:text-red-400">Sign Out</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

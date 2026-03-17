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
import type { NotificationPreferences } from "@repo/types";

export default function ProfileTab() {
  const { user, logout } = useAuth();
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

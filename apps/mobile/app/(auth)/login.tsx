import { useState } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
} from "react-native";
import { Link } from "expo-router";
import { MnmlLogo } from "@/components/MnmlLogo";
import { useAuth } from "@/lib/auth-context";
import { ApiClientError } from "@repo/api-client";

export default function LoginScreen() {
  const { login } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit() {
    if (!email || !password) return;
    setError("");
    setSubmitting(true);

    try {
      await login(email, password);
    } catch (err) {
      if (err instanceof ApiClientError) {
        setError(err.error.message);
      } else {
        setError("Something went wrong. Please try again.");
      }
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === "ios" ? "padding" : "height"}
      className="flex-1 bg-white dark:bg-zinc-900"
    >
      <ScrollView
        contentContainerClassName="flex-1 justify-center px-6"
        keyboardShouldPersistTaps="handled"
      >
        <View className="mb-8 items-center">
          <MnmlLogo height={40} />
          <Text className="mt-6 text-center text-2xl font-bold text-zinc-900 dark:text-zinc-100">
            Sign in
          </Text>
          <View className="mt-2 flex-row justify-center">
            <Text className="text-sm text-zinc-500 dark:text-zinc-400">
              Don't have an account?{" "}
            </Text>
            <Link href="/(auth)/register" asChild>
              <TouchableOpacity>
                <Text className="text-sm font-medium text-primary-600 dark:text-primary-400">
                  Register
                </Text>
              </TouchableOpacity>
            </Link>
          </View>
        </View>

        <View className="rounded-xl border border-zinc-200 bg-white p-6 dark:border-zinc-700 dark:bg-zinc-800">
          {error ? (
            <View className="mb-4 rounded-lg bg-bearish-light/30 px-4 py-3 dark:bg-bearish-dark/30">
              <Text className="text-sm text-bearish-dark dark:text-bearish-light">{error}</Text>
            </View>
          ) : null}

          <View className="mb-4">
            <Text className="mb-1.5 text-sm font-medium text-zinc-700 dark:text-zinc-300">
              Email
            </Text>
            <TextInput
              value={email}
              onChangeText={setEmail}
              placeholder="you@example.com"
              autoCapitalize="none"
              autoComplete="email"
              keyboardType="email-address"
              className="rounded-lg border border-zinc-300 px-3 py-2.5 text-sm text-zinc-900 dark:border-zinc-600 dark:bg-zinc-700 dark:text-zinc-100"
              placeholderTextColor="#9ca3af"
            />
          </View>

          <View className="mb-5">
            <Text className="mb-1.5 text-sm font-medium text-zinc-700 dark:text-zinc-300">
              Password
            </Text>
            <TextInput
              value={password}
              onChangeText={setPassword}
              placeholder="Enter your password"
              secureTextEntry
              autoComplete="password"
              className="rounded-lg border border-zinc-300 px-3 py-2.5 text-sm text-zinc-900 dark:border-zinc-600 dark:bg-zinc-700 dark:text-zinc-100"
              placeholderTextColor="#9ca3af"
            />
          </View>

          <TouchableOpacity
            onPress={handleSubmit}
            disabled={submitting}
            className="rounded-lg bg-primary-600 px-4 py-3"
            style={{ opacity: submitting ? 0.5 : 1 }}
          >
            <Text className="text-center text-sm font-medium text-white">
              {submitting ? "Signing in..." : "Sign in"}
            </Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

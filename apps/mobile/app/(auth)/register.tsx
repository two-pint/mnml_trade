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
import { useAuth } from "@/lib/auth-context";
import { ApiClientError } from "@repo/api-client";

export default function RegisterScreen() {
  const { register } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [username, setUsername] = useState("");
  const [error, setError] = useState("");
  const [fieldErrors, setFieldErrors] = useState<Record<string, string[]>>({});
  const [submitting, setSubmitting] = useState(false);

  function fieldError(field: string): string | undefined {
    return fieldErrors[field]?.[0];
  }

  async function handleSubmit() {
    if (!email || !password) return;
    setError("");
    setFieldErrors({});
    setSubmitting(true);

    try {
      await register(email, password, username || undefined);
    } catch (err) {
      if (err instanceof ApiClientError) {
        const apiErr = err.error as {
          message: string;
          errors?: Record<string, string[]>;
        };
        setError(apiErr.message);
        if (apiErr.errors) setFieldErrors(apiErr.errors);
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
        <View className="mb-8">
          <Text className="text-center text-2xl font-bold text-zinc-900 dark:text-zinc-100">
            Create your account
          </Text>
          <View className="mt-2 flex-row justify-center">
            <Text className="text-sm text-zinc-500 dark:text-zinc-400">
              Already have an account?{" "}
            </Text>
            <Link href="/(auth)/login" asChild>
              <TouchableOpacity>
                <Text className="text-sm font-medium text-primary-600 dark:text-primary-400">
                  Sign in
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
              className={`rounded-lg border px-3 py-2.5 text-sm text-zinc-900 dark:bg-zinc-700 dark:text-zinc-100 ${
                fieldError("email") ? "border-bearish" : "border-zinc-300 dark:border-zinc-600"
              }`}
              placeholderTextColor="#9ca3af"
            />
            {fieldError("email") ? (
              <Text className="mt-1 text-sm text-bearish">
                {fieldError("email")}
              </Text>
            ) : null}
          </View>

          <View className="mb-4">
            <View className="mb-1.5 flex-row">
              <Text className="text-sm font-medium text-zinc-700 dark:text-zinc-300">
                Username{" "}
              </Text>
              <Text className="text-sm text-zinc-400">(optional)</Text>
            </View>
            <TextInput
              value={username}
              onChangeText={setUsername}
              placeholder="Choose a username"
              autoCapitalize="none"
              autoComplete="username"
              className={`rounded-lg border px-3 py-2.5 text-sm text-zinc-900 dark:bg-zinc-700 dark:text-zinc-100 ${
                fieldError("username") ? "border-bearish" : "border-zinc-300 dark:border-zinc-600"
              }`}
              placeholderTextColor="#9ca3af"
            />
            {fieldError("username") ? (
              <Text className="mt-1 text-sm text-bearish">
                {fieldError("username")}
              </Text>
            ) : null}
          </View>

          <View className="mb-5">
            <Text className="mb-1.5 text-sm font-medium text-zinc-700 dark:text-zinc-300">
              Password
            </Text>
            <TextInput
              value={password}
              onChangeText={setPassword}
              placeholder="At least 8 characters"
              secureTextEntry
              autoComplete="new-password"
              className={`rounded-lg border px-3 py-2.5 text-sm text-zinc-900 dark:bg-zinc-700 dark:text-zinc-100 ${
                fieldError("password") ? "border-bearish" : "border-zinc-300 dark:border-zinc-600"
              }`}
              placeholderTextColor="#9ca3af"
            />
            {fieldError("password") ? (
              <Text className="mt-1 text-sm text-bearish">
                {fieldError("password")}
              </Text>
            ) : null}
          </View>

          <TouchableOpacity
            onPress={handleSubmit}
            disabled={submitting}
            className="rounded-lg bg-primary-600 px-4 py-3"
            style={{ opacity: submitting ? 0.5 : 1 }}
          >
            <Text className="text-center text-sm font-medium text-white">
              {submitting ? "Creating account..." : "Create account"}
            </Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

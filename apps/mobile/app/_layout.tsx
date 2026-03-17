import "../global.css";
import { Slot } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { AuthProvider, useAuth } from "@/lib/auth-context";
import { ThemeProvider, useTheme } from "@/lib/theme-context";
import { useRouter, useSegments } from "expo-router";
import { useEffect, useRef } from "react";
import { ActivityIndicator, View } from "react-native";
import { registerForPushNotifications, addNotificationResponseListener } from "@/lib/notifications";

function AuthGuard({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth();
  const segments = useSegments();
  const router = useRouter();
  const notifListenerRef = useRef<ReturnType<typeof addNotificationResponseListener> | null>(null);

  useEffect(() => {
    if (loading) return;

    const inAuthGroup = segments[0] === "(auth)";

    if (!user && !inAuthGroup) {
      router.replace("/(auth)/login");
    } else if (user && inAuthGroup) {
      router.replace("/(app)");
    }
  }, [user, loading, segments, router]);

  useEffect(() => {
    if (!user) return;

    registerForPushNotifications();

    notifListenerRef.current = addNotificationResponseListener((response) => {
      const data = response.notification.request.content.data;
      if (data?.ticker) {
        router.push(`/stocks/${encodeURIComponent(data.ticker as string)}` as never);
      }
    });

    return () => {
      notifListenerRef.current?.remove();
    };
  }, [user, router]);

  if (loading) {
    return (
      <View className="flex-1 items-center justify-center bg-zinc-50 dark:bg-zinc-900">
        <ActivityIndicator size="large" color="#4c6ef5" />
      </View>
    );
  }

  return <>{children}</>;
}

function ThemeWrapper({ children }: { children: React.ReactNode }) {
  const { isDark } = useTheme();
  return (
    <View className={isDark ? "flex-1 dark" : "flex-1"}>
      <StatusBar style={isDark ? "light" : "dark"} />
      {children}
    </View>
  );
}

export default function RootLayout() {
  return (
    <AuthProvider>
      <ThemeProvider>
        <ThemeWrapper>
          <AuthGuard>
            <Slot />
          </AuthGuard>
        </ThemeWrapper>
      </ThemeProvider>
    </AuthProvider>
  );
}

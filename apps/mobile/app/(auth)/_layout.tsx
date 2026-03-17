import { Stack } from "expo-router";
import { useTheme } from "@/lib/theme-context";

export default function AuthLayout() {
  const { isDark } = useTheme();
  return (
    <Stack
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: isDark ? "#18181b" : "#fafafa" },
      }}
    />
  );
}

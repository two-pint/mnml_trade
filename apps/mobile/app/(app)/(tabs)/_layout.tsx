import { Tabs } from "expo-router";
import { useTheme } from "@/lib/theme-context";

export default function TabsLayout() {
  const { isDark } = useTheme();
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: "#4c6ef5",
        tabBarInactiveTintColor: isDark ? "#a1a1aa" : "#71717a",
        tabBarStyle: {
          backgroundColor: isDark ? "#18181b" : "#ffffff",
          borderTopColor: isDark ? "#3f3f46" : "#e4e4e7",
        },
      }}
    >
      <Tabs.Screen name="index" options={{ title: "Home", tabBarLabel: "Home" }} />
      <Tabs.Screen name="portfolio" options={{ title: "Portfolio", tabBarLabel: "Portfolio" }} />
      <Tabs.Screen name="watchlist" options={{ title: "Watchlist", tabBarLabel: "Watchlist" }} />
      <Tabs.Screen name="profile" options={{ title: "Profile", tabBarLabel: "Profile" }} />
    </Tabs>
  );
}

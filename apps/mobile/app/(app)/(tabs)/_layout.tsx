import { Tabs } from "expo-router";

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: "#4c6ef5",
      }}
    >
      <Tabs.Screen name="index" options={{ title: "Home", tabBarLabel: "Home" }} />
      <Tabs.Screen name="portfolio" options={{ title: "Portfolio", tabBarLabel: "Portfolio" }} />
      <Tabs.Screen name="watchlist" options={{ title: "Watchlist", tabBarLabel: "Watchlist" }} />
      <Tabs.Screen name="profile" options={{ title: "Profile", tabBarLabel: "Profile" }} />
    </Tabs>
  );
}

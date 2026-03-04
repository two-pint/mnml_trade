import { View, Text, TouchableOpacity } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useAuth } from "@/lib/auth-context";

export default function HomeScreen() {
  const { user, logout } = useAuth();

  return (
    <SafeAreaView className="flex-1 bg-white">
      <View className="border-b border-gray-200 px-6 py-4">
        <View className="flex-row items-center justify-between">
          <Text className="text-lg font-semibold text-gray-900">
            mnml trade
          </Text>
          <TouchableOpacity
            onPress={logout}
            className="rounded-lg border border-gray-300 px-3 py-1.5"
          >
            <Text className="text-sm font-medium text-gray-700">Sign out</Text>
          </TouchableOpacity>
        </View>
        <Text className="mt-1 text-sm text-gray-500">{user?.email}</Text>
      </View>

      <View className="flex-1 items-center justify-center px-6">
        <Text className="text-3xl font-bold text-gray-900">
          Welcome{user?.username ? `, ${user.username}` : ""}
        </Text>
        <Text className="mt-3 text-gray-500">
          You're signed in. This is your dashboard.
        </Text>
      </View>
    </SafeAreaView>
  );
}

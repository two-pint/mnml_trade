import { View, Text } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

export default function PortfolioTab() {
  return (
    <SafeAreaView className="flex-1 bg-white">
      <View className="flex-1 items-center justify-center px-6">
        <Text className="text-lg font-semibold text-gray-900">Portfolio</Text>
        <Text className="mt-2 text-center text-gray-500">Coming soon</Text>
      </View>
    </SafeAreaView>
  );
}

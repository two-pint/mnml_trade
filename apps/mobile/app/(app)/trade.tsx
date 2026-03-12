import { useCallback, useEffect, useState } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useLocalSearchParams, useRouter } from "expo-router";
import type { PaperPortfolio, TradeResult } from "@repo/types";
import { paperTradingApi, stocksApi } from "@/lib/api";
import { ApiClientError } from "@repo/api-client";

type Side = "buy" | "sell";

export default function TradeScreen() {
  const { ticker: rawTicker } = useLocalSearchParams<{ ticker: string }>();
  const ticker = rawTicker ? decodeURIComponent(rawTicker) : "";
  const router = useRouter();

  const [side, setSide] = useState<Side>("buy");
  const [quantity, setQuantity] = useState("");
  const [price, setPrice] = useState<number | null>(null);
  const [portfolio, setPortfolio] = useState<PaperPortfolio | null>(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<TradeResult | null>(null);

  useEffect(() => {
    Promise.all([
      stocksApi.getStock(ticker),
      paperTradingApi.listPortfolios(),
    ])
      .then(([stock, res]) => {
        setPrice(stock.price);
        if (res.data.length > 0) setPortfolio(res.data[0]!);
      })
      .catch(() => setError("Failed to load data"))
      .finally(() => setLoading(false));
  }, [ticker]);

  const qty = parseInt(quantity, 10);
  const validQty = !Number.isNaN(qty) && qty >= 1 && qty <= 10_000;
  const totalCost = price != null && validQty ? qty * price : null;
  const cashAvailable = portfolio ? parseFloat(portfolio.cash_balance) : 0;
  const sharesOwned = portfolio?.holdings?.find(
    (h) => h.ticker.toUpperCase() === ticker.toUpperCase(),
  );
  const sharesQty = sharesOwned ? parseFloat(sharesOwned.quantity) : 0;

  const validationError = (() => {
    if (!validQty && quantity !== "") {
      const n = parseInt(quantity, 10);
      if (Number.isNaN(n) || n < 1) return "Quantity must be at least 1";
      if (n > 10_000) return "Maximum 10,000 shares per trade";
    }
    if (side === "buy" && totalCost != null && totalCost > cashAvailable) {
      return `Insufficient cash ($${cashAvailable.toFixed(2)} available)`;
    }
    if (side === "sell" && validQty && qty > sharesQty) {
      return `Insufficient shares (${sharesQty} owned)`;
    }
    return null;
  })();

  const canSubmit = validQty && price != null && portfolio != null && !submitting && !validationError;

  const handleSubmit = async () => {
    if (!canSubmit) return;
    setSubmitting(true);
    setError(null);
    try {
      const res = await paperTradingApi.executeTrade(portfolio!.id, {
        ticker,
        side,
        quantity: qty,
      });
      setResult(res.data);
    } catch (err) {
      if (err instanceof ApiClientError) {
        setError(err.error.message ?? err.message);
      } else {
        setError("Trade failed. Please try again.");
      }
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <SafeAreaView className="flex-1 bg-white">
        <View className="flex-1 items-center justify-center">
          <ActivityIndicator size="large" color="#4c6ef5" />
        </View>
      </SafeAreaView>
    );
  }

  if (result) {
    return (
      <SafeAreaView className="flex-1 bg-white">
        <ScrollView contentContainerClassName="flex-1 items-center justify-center px-6 py-8">
          <View className="h-16 w-16 items-center justify-center rounded-full bg-green-100">
            <Text className="text-3xl">✓</Text>
          </View>
          <Text className="mt-4 text-xl font-bold text-gray-900">Trade Executed</Text>
          <View className="mt-6 w-full rounded-lg bg-gray-50 p-4">
            <View className="flex-row justify-between py-1.5">
              <Text className="text-gray-500">Action</Text>
              <Text className={`font-semibold capitalize ${result.transaction.side === "buy" ? "text-green-600" : "text-red-600"}`}>
                {result.transaction.side}
              </Text>
            </View>
            <View className="flex-row justify-between py-1.5">
              <Text className="text-gray-500">Ticker</Text>
              <Text className="font-semibold text-gray-900">{result.transaction.ticker}</Text>
            </View>
            <View className="flex-row justify-between py-1.5">
              <Text className="text-gray-500">Quantity</Text>
              <Text className="font-semibold text-gray-900">{result.transaction.quantity}</Text>
            </View>
            <View className="flex-row justify-between py-1.5">
              <Text className="text-gray-500">Price</Text>
              <Text className="font-semibold text-gray-900">${parseFloat(result.transaction.price_per_share).toFixed(2)}</Text>
            </View>
            <View className="mt-2 border-t border-gray-200 pt-2 flex-row justify-between">
              <Text className="font-semibold text-gray-700">Total</Text>
              <Text className="font-bold text-gray-900">${parseFloat(result.transaction.total_amount).toFixed(2)}</Text>
            </View>
          </View>
          <View className="mt-8 w-full gap-3">
            <TouchableOpacity
              onPress={() => {
                router.dismissAll();
                router.replace("/(app)/(tabs)/portfolio" as never);
              }}
              className="rounded-lg bg-primary-600 py-3"
            >
              <Text className="text-center font-semibold text-white">View Portfolio</Text>
            </TouchableOpacity>
            <TouchableOpacity
              onPress={() => router.back()}
              className="rounded-lg border border-gray-300 py-3"
            >
              <Text className="text-center font-medium text-gray-700">Continue Analyzing</Text>
            </TouchableOpacity>
          </View>
        </ScrollView>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView className="flex-1 bg-white">
      <KeyboardAvoidingView
        behavior={Platform.OS === "ios" ? "padding" : undefined}
        className="flex-1"
      >
        <ScrollView contentContainerClassName="px-4 py-4">
          {/* Header */}
          <View className="flex-row items-center justify-between mb-6">
            <TouchableOpacity onPress={() => router.back()}>
              <Text className="text-primary-600 font-medium">Cancel</Text>
            </TouchableOpacity>
            <Text className="text-lg font-bold text-gray-900">Trade {ticker}</Text>
            <View style={{ width: 50 }} />
          </View>

          {!portfolio ? (
            <View className="items-center py-8">
              <Text className="text-gray-500">No portfolio found</Text>
              <Text className="mt-1 text-xs text-gray-400">Create a portfolio from the Portfolio tab first</Text>
            </View>
          ) : (
            <>
              {/* Buy/Sell Toggle */}
              <View className="flex-row rounded-lg bg-gray-100 p-1">
                <TouchableOpacity
                  onPress={() => { setSide("buy"); setError(null); }}
                  className={`flex-1 items-center rounded-md py-2.5 ${side === "buy" ? "bg-green-500" : ""}`}
                >
                  <Text className={`font-semibold ${side === "buy" ? "text-white" : "text-gray-600"}`}>Buy</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  onPress={() => { setSide("sell"); setError(null); }}
                  className={`flex-1 items-center rounded-md py-2.5 ${side === "sell" ? "bg-red-500" : ""}`}
                >
                  <Text className={`font-semibold ${side === "sell" ? "text-white" : "text-gray-600"}`}>Sell</Text>
                </TouchableOpacity>
              </View>

              {/* Price */}
              <View className="mt-6 flex-row items-baseline justify-between">
                <Text className="text-sm text-gray-500">Current Price</Text>
                <Text className="text-2xl font-bold text-gray-900">
                  {price != null ? `$${price.toFixed(2)}` : "—"}
                </Text>
              </View>

              {/* Context */}
              <View className="mt-4 rounded-lg bg-gray-50 px-4 py-3">
                {side === "buy" ? (
                  <View className="flex-row justify-between">
                    <Text className="text-sm text-gray-500">Cash Available</Text>
                    <Text className="font-semibold text-gray-900">${cashAvailable.toFixed(2)}</Text>
                  </View>
                ) : (
                  <View className="flex-row justify-between">
                    <Text className="text-sm text-gray-500">Shares Owned</Text>
                    <Text className="font-semibold text-gray-900">{sharesQty}</Text>
                  </View>
                )}
              </View>

              {/* Quantity */}
              <View className="mt-5">
                <Text className="text-sm font-medium text-gray-600">Shares</Text>
                <TextInput
                  value={quantity}
                  onChangeText={(t) => { setQuantity(t); setError(null); }}
                  placeholder="Enter quantity"
                  placeholderTextColor="#9ca3af"
                  keyboardType="number-pad"
                  className="mt-1 rounded-lg border border-gray-300 bg-white px-4 py-3 text-base font-medium text-gray-900"
                  autoFocus
                />
              </View>

              {/* Total Preview */}
              {totalCost != null && (
                <View className="mt-4 flex-row items-baseline justify-between rounded-lg border border-gray-200 bg-gray-50 px-4 py-3">
                  <Text className="text-sm font-medium text-gray-600">Estimated Total</Text>
                  <Text className="text-lg font-bold text-gray-900">
                    ${totalCost.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                  </Text>
                </View>
              )}

              {/* Errors */}
              {validationError && (
                <Text className="mt-3 text-sm font-medium text-red-600">{validationError}</Text>
              )}
              {error && (
                <Text className="mt-3 text-sm font-medium text-red-600">{error}</Text>
              )}

              {/* Submit */}
              <TouchableOpacity
                onPress={handleSubmit}
                disabled={!canSubmit}
                className={`mt-6 rounded-lg py-3.5 ${side === "buy" ? "bg-green-500" : "bg-red-500"}`}
                style={{ opacity: canSubmit ? 1 : 0.5 }}
              >
                <Text className="text-center font-bold text-white">
                  {submitting
                    ? "Executing..."
                    : `${side === "buy" ? "Buy" : "Sell"} ${validQty ? qty : ""} ${ticker}`}
                </Text>
              </TouchableOpacity>
            </>
          )}
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

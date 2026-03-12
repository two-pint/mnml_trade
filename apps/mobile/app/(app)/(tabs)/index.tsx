"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  View,
  Text,
  TextInput,
  FlatList,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useRouter } from "expo-router";
import { MnmlLogo } from "@/components/MnmlLogo";
import { useAuth } from "@/lib/auth-context";
import { stocksApi, engagementApi } from "@/lib/api";
import type { SearchResult, TrendingStock, HistoryEntry } from "@repo/types";

const DEBOUNCE_MS = 300;

export default function HomeTab() {
  const { user, logout } = useAuth();
  const router = useRouter();
  const [query, setQuery] = useState("");
  const [searchResults, setSearchResults] = useState<SearchResult[]>([]);
  const [trending, setTrending] = useState<TrendingStock[]>([]);
  const [searching, setSearching] = useState(false);
  const [trendingLoading, setTrendingLoading] = useState(true);
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const loadTrending = useCallback(() => {
    setTrendingLoading(true);
    stocksApi
      .getTrending()
      .then(setTrending)
      .catch(() => setTrending([]))
      .finally(() => setTrendingLoading(false));
  }, []);

  const loadHistory = useCallback(() => {
    engagementApi
      .listHistory()
      .then(({ data }) => setHistory(data.slice(0, 10)))
      .catch(() => setHistory([]));
  }, []);

  useEffect(() => {
    loadTrending();
    loadHistory();
  }, [loadTrending, loadHistory]);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    const q = query.trim();
    if (!q) {
      setSearchResults([]);
      setSearching(false);
      return;
    }
    setSearching(true);
    debounceRef.current = setTimeout(() => {
      debounceRef.current = null;
      stocksApi
        .searchStocks(q)
        .then((data) => setSearchResults(data ?? []))
        .catch(() => setSearchResults([]))
        .finally(() => setSearching(false));
    }, DEBOUNCE_MS);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [query]);

  const showSearch = query.trim().length > 0;
  const data = showSearch ? searchResults : trending;

  const handleSelectTicker = (ticker: string) => {
    setQuery("");
    router.push(`/stocks/${encodeURIComponent(ticker)}` as never);
  };

  const renderItem = ({ item }: { item: SearchResult | TrendingStock }) => {
    const ticker = item.ticker;
    const name = "name" in item ? item.name : ticker;
    return (
      <TouchableOpacity
        onPress={() => handleSelectTicker(ticker)}
        className="border-b border-gray-100 px-6 py-4 active:bg-gray-50"
      >
        <View className="flex-row items-center justify-between">
          <View>
            <Text className="font-semibold text-gray-900">{ticker}</Text>
            <Text className="text-sm text-gray-500" numberOfLines={1}>
              {name}
            </Text>
          </View>
          {"price" in item && item.price != null && (
            <View className="items-end">
              <Text className="font-medium text-gray-900">
                ${item.price.toFixed(2)}
              </Text>
              {"change" in item && item.change != null && (
                <Text
                  className={`text-sm ${item.change >= 0 ? "text-green-600" : "text-red-600"}`}
                >
                  {item.change >= 0 ? "+" : ""}
                  {item.change.toFixed(2)} ({item.change_percent ?? ""})
                </Text>
              )}
            </View>
          )}
        </View>
      </TouchableOpacity>
    );
  };

  return (
    <SafeAreaView className="flex-1 bg-white" edges={["top"]}>
      <KeyboardAvoidingView
        behavior={Platform.OS === "ios" ? "padding" : undefined}
        className="flex-1"
      >
        <View className="border-b border-gray-200 px-4 py-3">
          <View className="flex-row items-center justify-between">
            <MnmlLogo height={28} />
            <TouchableOpacity
              onPress={() => logout()}
              className="rounded-lg border border-gray-300 px-3 py-1.5"
            >
              <Text className="text-sm font-medium text-gray-700">Sign out</Text>
            </TouchableOpacity>
          </View>
          <Text className="mt-1 text-sm text-gray-500">{user?.email}</Text>
          <TextInput
            value={query}
            onChangeText={setQuery}
            placeholder="Search stocks..."
            placeholderTextColor="#9ca3af"
            className="mt-3 rounded-lg border border-gray-300 bg-gray-50 px-4 py-3 text-base text-gray-900"
          />
        </View>

        {!showSearch && history.length > 0 && (
          <View className="border-b border-gray-100 px-4 py-3">
            <Text className="mb-2 text-sm font-medium text-gray-500">Recently viewed</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false}>
              <View className="flex-row gap-2">
                {history.map((h) => (
                  <TouchableOpacity
                    key={h.id}
                    onPress={() => handleSelectTicker(h.ticker)}
                    className="rounded-lg border border-gray-200 bg-gray-50 px-4 py-2"
                  >
                    <Text className="text-sm font-medium text-gray-700">{h.ticker}</Text>
                  </TouchableOpacity>
                ))}
              </View>
            </ScrollView>
          </View>
        )}

        {showSearch && searching && (
          <View className="items-center py-8">
            <ActivityIndicator size="small" color="#4c6ef5" />
          </View>
        )}

        {showSearch && !searching && searchResults.length === 0 && (
          <View className="px-6 py-8">
            <Text className="text-center text-gray-500">No results</Text>
          </View>
        )}

        {!showSearch && trendingLoading && (
          <View className="items-center py-8">
            <ActivityIndicator size="small" color="#4c6ef5" />
          </View>
        )}

        {((showSearch && searchResults.length > 0) || (!showSearch && trending.length > 0)) && (
          <FlatList
            data={data}
            keyExtractor={(item) => item.ticker}
            renderItem={renderItem}
            ListHeaderComponent={
              !showSearch && trending.length > 0 ? (
                <View className="border-b border-gray-100 px-6 py-3">
                  <Text className="text-sm font-medium text-gray-500">
                    Popular stocks
                  </Text>
                </View>
              ) : null
            }
          />
        )}

        {!showSearch && !trendingLoading && trending.length === 0 && (
          <View className="flex-1 items-center justify-center px-6">
            <Text className="text-center text-gray-500">
              No trending data. Search for a stock above.
            </Text>
          </View>
        )}
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

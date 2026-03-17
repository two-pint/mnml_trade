"use client";

import { useCallback, useEffect, useState } from "react";
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  ActivityIndicator,
  RefreshControl,
  Alert,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useRouter } from "expo-router";
import type { WatchlistItem, StockOverview } from "@repo/types";
import { engagementApi, stocksApi } from "@/lib/api";

interface WatchlistRow extends WatchlistItem {
  price?: number | null;
  change?: number | null;
  change_percent?: string | null;
  name?: string | null;
}

export default function WatchlistTab() {
  const router = useRouter();
  const [items, setItems] = useState<WatchlistRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    try {
      const { data } = await engagementApi.listWatchlist();
      const rows: WatchlistRow[] = data.map((w) => ({ ...w }));
      setItems(rows);

      const overviews = await Promise.allSettled(
        rows.map((r) => stocksApi.getStock(r.ticker)),
      );
      setItems((prev) =>
        prev.map((row, i) => {
          const result = overviews[i];
          if (result?.status === "fulfilled") {
            const ov = result.value as StockOverview;
            return {
              ...row,
              price: ov.price,
              change: ov.change,
              change_percent: ov.change_percent,
              name: ov.name ?? null,
            };
          }
          return row;
        }),
      );
    } catch {
      // silently ignore
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    load();
  }, [load]);

  const handleRemove = (ticker: string) => {
    Alert.alert("Remove from Watchlist", `Remove ${ticker}?`, [
      { text: "Cancel", style: "cancel" },
      {
        text: "Remove",
        style: "destructive",
        onPress: async () => {
          try {
            await engagementApi.removeFromWatchlist(ticker);
            setItems((prev) => prev.filter((i) => i.ticker !== ticker));
          } catch {
            // ignore
          }
        },
      },
    ]);
  };

  const renderItem = ({ item }: { item: WatchlistRow }) => (
    <TouchableOpacity
      onPress={() => router.push(`/stocks/${encodeURIComponent(item.ticker)}` as never)}
      onLongPress={() => handleRemove(item.ticker)}
      className="border-b border-zinc-100 px-4 py-4 active:bg-zinc-50"
    >
      <View className="flex-row items-center justify-between">
        <View className="flex-1">
          <Text className="text-base font-semibold text-zinc-900">{item.ticker}</Text>
          {item.name && (
            <Text className="mt-0.5 text-sm text-zinc-500" numberOfLines={1}>
              {item.name}
            </Text>
          )}
        </View>
        <View className="items-end">
          {item.price != null ? (
            <>
              <Text className="text-base font-medium text-zinc-900">
                ${item.price.toFixed(2)}
              </Text>
              {item.change != null && (
                <Text
                  className={`text-sm ${item.change >= 0 ? "text-green-600" : "text-red-600"}`}
                >
                  {item.change >= 0 ? "+" : ""}{item.change.toFixed(2)}
                  {item.change_percent ? ` (${item.change_percent})` : ""}
                </Text>
              )}
            </>
          ) : (
            <ActivityIndicator size="small" color="#9ca3af" />
          )}
        </View>
        <TouchableOpacity
          onPress={() => handleRemove(item.ticker)}
          className="ml-3 rounded-lg p-2"
          hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
        >
          <Text className="text-lg text-zinc-300">×</Text>
        </TouchableOpacity>
      </View>
    </TouchableOpacity>
  );

  if (loading) {
    return (
      <SafeAreaView className="flex-1 bg-white" edges={["top"]}>
        <View className="border-b border-zinc-200 px-4 py-4">
          <Text className="text-2xl font-bold text-zinc-900">Watchlist</Text>
        </View>
        <View className="flex-1 items-center justify-center">
          <ActivityIndicator size="large" color="#4c6ef5" />
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView className="flex-1 bg-white" edges={["top"]}>
      <View className="border-b border-zinc-200 px-4 py-4">
        <Text className="text-2xl font-bold text-zinc-900">Watchlist</Text>
      </View>
      {items.length === 0 ? (
        <View className="flex-1 items-center justify-center px-8">
          <Text className="text-4xl">☆</Text>
          <Text className="mt-4 text-lg font-semibold text-zinc-900">
            No stocks in your watchlist
          </Text>
          <Text className="mt-2 text-center text-zinc-500">
            Add stocks to your watchlist from any analysis page to track them here.
          </Text>
        </View>
      ) : (
        <FlatList
          data={items}
          keyExtractor={(item) => item.id}
          renderItem={renderItem}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
          }
        />
      )}
    </SafeAreaView>
  );
}

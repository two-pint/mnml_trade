import { useCallback, useEffect, useState } from "react";
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  ActivityIndicator,
  RefreshControl,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useRouter } from "expo-router";
import type { TransactionDetail, PaginationMeta } from "@repo/types";
import { paperTradingApi } from "@/lib/api";

function fmt(value: string | null | undefined): string {
  if (value == null) return "—";
  const n = parseFloat(value);
  if (Number.isNaN(n)) return "—";
  return n.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

export default function TransactionsScreen() {
  const router = useRouter();
  const [portfolioId, setPortfolioId] = useState<string | null>(null);
  const [transactions, setTransactions] = useState<TransactionDetail[]>([]);
  const [meta, setMeta] = useState<PaginationMeta | null>(null);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);

  useEffect(() => {
    paperTradingApi
      .listPortfolios()
      .then((res) => {
        if (res.data.length > 0) {
          setPortfolioId(res.data[0]!.id);
        }
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const loadPage = useCallback(
    async (p: number, append = false) => {
      if (!portfolioId) return;
      if (append) setLoadingMore(true);
      try {
        const res = await paperTradingApi.listTransactions(portfolioId, {
          page: p,
          per_page: 20,
        });
        setTransactions((prev) => (append ? [...prev, ...res.data] : res.data));
        setMeta(res.meta);
        setPage(p);
      } catch {
        // ignore
      } finally {
        setLoadingMore(false);
        setRefreshing(false);
        setLoading(false);
      }
    },
    [portfolioId],
  );

  useEffect(() => {
    if (portfolioId) {
      setLoading(true);
      loadPage(1);
    }
  }, [portfolioId, loadPage]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    loadPage(1);
  }, [loadPage]);

  const onEndReached = useCallback(() => {
    if (loadingMore || !meta) return;
    if (page < meta.total_pages) {
      loadPage(page + 1, true);
    }
  }, [loadingMore, meta, page, loadPage]);

  const renderItem = ({ item: tx }: { item: TransactionDetail }) => {
    const d = new Date(tx.executed_at);
    return (
      <View className="flex-row items-center justify-between border-b border-zinc-50 px-4 py-4">
        <View className="flex-1">
          <View className="flex-row items-center gap-2">
            <Text className="font-semibold text-zinc-900">{tx.ticker}</Text>
            <View
              className={`rounded-full px-2 py-0.5 ${
                tx.transaction_type === "buy" ? "bg-green-100" : "bg-red-100"
              }`}
            >
              <Text
                className={`text-[10px] font-bold uppercase ${
                  tx.transaction_type === "buy" ? "text-green-800" : "text-red-800"
                }`}
              >
                {tx.transaction_type}
              </Text>
            </View>
          </View>
          <Text className="mt-0.5 text-xs text-zinc-400">
            {d.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" })}
            {" "}
            {d.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" })}
          </Text>
        </View>
        <View className="items-end">
          <Text className="font-medium text-zinc-900">${fmt(tx.total_amount)}</Text>
          <Text className="text-xs text-zinc-500">
            {fmt(tx.quantity)} @ ${fmt(tx.price_per_share)}
          </Text>
        </View>
      </View>
    );
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

  return (
    <SafeAreaView className="flex-1 bg-white" edges={["top"]}>
      <View className="border-b border-zinc-200 px-4 py-3">
        <TouchableOpacity onPress={() => router.back()} className="mb-2">
          <Text className="text-primary-600">← Back</Text>
        </TouchableOpacity>
        <Text className="text-xl font-bold text-zinc-900">Transaction History</Text>
        {meta && (
          <Text className="mt-1 text-xs text-zinc-400">
            Page {page} of {meta.total_pages}
          </Text>
        )}
      </View>

      {transactions.length === 0 ? (
        <View className="flex-1 items-center justify-center">
          <Text className="text-zinc-500">No transactions yet</Text>
          <Text className="mt-1 text-xs text-zinc-400">
            Place your first trade from a stock page
          </Text>
        </View>
      ) : (
        <FlatList
          data={transactions}
          keyExtractor={(tx) => tx.id}
          renderItem={renderItem}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
          }
          onEndReached={onEndReached}
          onEndReachedThreshold={0.5}
          ListFooterComponent={
            loadingMore ? (
              <View className="py-4">
                <ActivityIndicator size="small" color="#4c6ef5" />
              </View>
            ) : null
          }
        />
      )}
    </SafeAreaView>
  );
}

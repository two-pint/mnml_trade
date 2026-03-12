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
import type {
  PaperPortfolio,
  EnrichedHolding,
  PortfolioPerformance,
  TransactionDetail,
} from "@repo/types";
import { paperTradingApi } from "@/lib/api";

function fmt(value: string | null | undefined): string {
  if (value == null) return "—";
  const n = parseFloat(value);
  if (Number.isNaN(n)) return "—";
  return n.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function fmtPct(value: string | null | undefined): string {
  if (value == null) return "—";
  const n = parseFloat(value);
  if (Number.isNaN(n)) return "—";
  return `${n >= 0 ? "+" : ""}${n.toFixed(2)}%`;
}

function fmtDollar(value: string | null | undefined): string {
  if (value == null) return "$—";
  const n = parseFloat(value);
  if (Number.isNaN(n)) return "$—";
  return `${n >= 0 ? "+$" : "-$"}${Math.abs(n).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function colorCls(value: string | null | undefined): string {
  if (value == null) return "text-gray-500";
  const n = parseFloat(value);
  if (Number.isNaN(n)) return "text-gray-500";
  return n > 0 ? "text-green-600" : n < 0 ? "text-red-600" : "text-gray-500";
}

type Section =
  | { type: "header" }
  | { type: "stats" }
  | { type: "holdingsHeader" }
  | { type: "holding"; data: EnrichedHolding }
  | { type: "holdingsEmpty" }
  | { type: "txHeader" }
  | { type: "tx"; data: TransactionDetail }
  | { type: "txEmpty" }
  | { type: "txMore" };

export default function PortfolioTab() {
  const router = useRouter();
  const [portfolio, setPortfolio] = useState<PaperPortfolio | null>(null);
  const [holdings, setHoldings] = useState<EnrichedHolding[]>([]);
  const [performance, setPerformance] = useState<PortfolioPerformance | null>(null);
  const [recentTx, setRecentTx] = useState<TransactionDetail[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);

  const load = useCallback(async () => {
    try {
      const res = await paperTradingApi.listPortfolios();
      const list = res.data;
      if (list.length === 0) {
        setPortfolio(null);
        setHoldings([]);
        setPerformance(null);
        setRecentTx([]);
        return;
      }
      const p = list[0]!;
      setPortfolio(p);
      const [h, perf, tx] = await Promise.all([
        paperTradingApi.listHoldings(p.id),
        paperTradingApi.getPerformance(p.id),
        paperTradingApi.listTransactions(p.id, { per_page: 5 }),
      ]);
      setHoldings(h.data);
      setPerformance(perf.data);
      setRecentTx(tx.data);
    } catch {
      setError("Failed to load portfolio");
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

  const handleCreate = async () => {
    setCreating(true);
    try {
      await paperTradingApi.createPortfolio({ name: "My Portfolio" });
      await load();
    } catch {
      setError("Failed to create portfolio");
    } finally {
      setCreating(false);
    }
  };

  if (loading) {
    return (
      <SafeAreaView className="flex-1 bg-white" edges={["top"]}>
        <View className="flex-1 items-center justify-center">
          <ActivityIndicator size="large" color="#4c6ef5" />
        </View>
      </SafeAreaView>
    );
  }

  if (!portfolio) {
    return (
      <SafeAreaView className="flex-1 bg-white" edges={["top"]}>
        <View className="flex-1 items-center justify-center px-6">
          <Text className="text-xl font-bold text-gray-900">Paper Trading</Text>
          <Text className="mt-2 text-center text-gray-500">
            Create your first portfolio to start practicing trades with $100,000 in virtual cash.
          </Text>
          <TouchableOpacity
            onPress={handleCreate}
            disabled={creating}
            className="mt-6 rounded-lg bg-primary-600 px-6 py-3"
            style={{ opacity: creating ? 0.5 : 1 }}
          >
            <Text className="font-semibold text-white">
              {creating ? "Creating..." : "Create Portfolio"}
            </Text>
          </TouchableOpacity>
          {error && <Text className="mt-3 text-red-600">{error}</Text>}
        </View>
      </SafeAreaView>
    );
  }

  const totalValue = performance ? parseFloat(performance.total_value) : 0;
  const startingBalance = parseFloat(portfolio.starting_balance);
  const totalReturnDollar = performance ? (totalValue - startingBalance).toFixed(2) : "0";
  const totalReturnPct = performance?.total_return ?? "0";

  const sections: Section[] = [
    { type: "header" },
    { type: "stats" },
    { type: "holdingsHeader" },
    ...(holdings.length > 0
      ? holdings.map((h) => ({ type: "holding" as const, data: h }))
      : [{ type: "holdingsEmpty" as const }]),
    { type: "txHeader" },
    ...(recentTx.length > 0
      ? [
          ...recentTx.map((t) => ({ type: "tx" as const, data: t })),
          { type: "txMore" as const },
        ]
      : [{ type: "txEmpty" as const }]),
  ];

  const renderItem = ({ item }: { item: Section }) => {
    switch (item.type) {
      case "header":
        return (
          <View className="border-b border-gray-200 px-4 py-4">
            <Text className="text-xs font-medium uppercase tracking-wide text-gray-500">
              {portfolio.name}
            </Text>
            <Text className="mt-1 text-3xl font-bold text-gray-900">
              ${fmt(performance?.total_value)}
            </Text>
            <View className="mt-1 flex-row items-baseline gap-2">
              <Text className={`text-base font-semibold ${colorCls(totalReturnDollar)}`}>
                {fmtDollar(totalReturnDollar)}
              </Text>
              <Text className={`text-sm ${colorCls(totalReturnPct)}`}>
                ({fmtPct(totalReturnPct)})
              </Text>
            </View>
            <View className="mt-3 flex-row gap-4">
              <Text className="text-sm text-gray-500">
                Cash: <Text className="font-semibold text-gray-900">${fmt(performance?.cash_balance)}</Text>
              </Text>
              <Text className="text-sm text-gray-500">
                Invested: <Text className="font-semibold text-gray-900">${fmt(performance?.holdings_value)}</Text>
              </Text>
            </View>
          </View>
        );

      case "stats":
        if (!performance) return null;
        return (
          <View className="flex-row flex-wrap gap-3 px-4 py-3">
            <View className="flex-1 rounded-lg border border-gray-200 bg-white p-3" style={{ minWidth: 140 }}>
              <Text className="text-[10px] font-medium uppercase text-gray-500">Win Rate</Text>
              <Text className="mt-0.5 text-lg font-bold text-gray-900">{fmtPct(performance.win_rate).replace("+", "")}</Text>
              <Text className="text-xs text-gray-400">{performance.profitable_sells}/{performance.total_sells} sells</Text>
            </View>
            <View className="flex-1 rounded-lg border border-gray-200 bg-white p-3" style={{ minWidth: 140 }}>
              <Text className="text-[10px] font-medium uppercase text-gray-500">Total Trades</Text>
              <Text className="mt-0.5 text-lg font-bold text-gray-900">{performance.total_trades}</Text>
            </View>
            {performance.best_trade && (
              <View className="flex-1 rounded-lg border border-gray-200 bg-white p-3" style={{ minWidth: 140 }}>
                <Text className="text-[10px] font-medium uppercase text-gray-500">Best Trade</Text>
                <Text className="mt-0.5 font-bold text-gray-900">{performance.best_trade.ticker}</Text>
                <Text className={`text-xs ${colorCls(performance.best_trade.gain_percent)}`}>{fmtPct(performance.best_trade.gain_percent)}</Text>
              </View>
            )}
            {performance.worst_trade && (
              <View className="flex-1 rounded-lg border border-gray-200 bg-white p-3" style={{ minWidth: 140 }}>
                <Text className="text-[10px] font-medium uppercase text-gray-500">Worst Trade</Text>
                <Text className="mt-0.5 font-bold text-gray-900">{performance.worst_trade.ticker}</Text>
                <Text className={`text-xs ${colorCls(performance.worst_trade.gain_percent)}`}>{fmtPct(performance.worst_trade.gain_percent)}</Text>
              </View>
            )}
          </View>
        );

      case "holdingsHeader":
        return (
          <View className="flex-row items-center justify-between border-b border-gray-100 px-4 py-3">
            <Text className="text-sm font-semibold text-gray-700">Holdings</Text>
            <Text className="text-xs text-gray-400">
              {holdings.length} position{holdings.length !== 1 ? "s" : ""}
            </Text>
          </View>
        );

      case "holding": {
        const h = item.data;
        return (
          <TouchableOpacity
            onPress={() => router.push(`/stocks/${encodeURIComponent(h.ticker)}` as never)}
            className="flex-row items-center justify-between border-b border-gray-50 px-4 py-3 active:bg-gray-50"
          >
            <View>
              <Text className="font-semibold text-gray-900">{h.ticker}</Text>
              <Text className="text-xs text-gray-500">{fmt(h.quantity)} shares @ ${fmt(h.average_cost)}</Text>
            </View>
            <View className="items-end">
              <Text className="font-medium text-gray-900">${fmt(h.current_value)}</Text>
              <Text className={`text-xs font-medium ${colorCls(h.gain_loss_percent)}`}>
                {fmtDollar(h.gain_loss)} ({fmtPct(h.gain_loss_percent)})
              </Text>
            </View>
          </TouchableOpacity>
        );
      }

      case "holdingsEmpty":
        return (
          <View className="items-center py-8">
            <Text className="text-gray-500">No holdings yet</Text>
            <Text className="mt-1 text-xs text-gray-400">Search for a stock and place a trade</Text>
          </View>
        );

      case "txHeader":
        return (
          <View className="mt-2 border-b border-gray-100 px-4 py-3">
            <Text className="text-sm font-semibold text-gray-700">Recent Transactions</Text>
          </View>
        );

      case "tx": {
        const tx = item.data;
        const d = new Date(tx.executed_at);
        return (
          <View className="flex-row items-center justify-between border-b border-gray-50 px-4 py-3">
            <View>
              <View className="flex-row items-center gap-2">
                <Text className="font-semibold text-gray-900">{tx.ticker}</Text>
                <View className={`rounded-full px-2 py-0.5 ${tx.transaction_type === "buy" ? "bg-green-100" : "bg-red-100"}`}>
                  <Text className={`text-[10px] font-bold uppercase ${tx.transaction_type === "buy" ? "text-green-800" : "text-red-800"}`}>
                    {tx.transaction_type}
                  </Text>
                </View>
              </View>
              <Text className="text-xs text-gray-400">
                {d.toLocaleDateString("en-US", { month: "short", day: "numeric" })}
              </Text>
            </View>
            <View className="items-end">
              <Text className="font-medium text-gray-900">${fmt(tx.total_amount)}</Text>
              <Text className="text-xs text-gray-500">{fmt(tx.quantity)} @ ${fmt(tx.price_per_share)}</Text>
            </View>
          </View>
        );
      }

      case "txEmpty":
        return (
          <View className="items-center py-6">
            <Text className="text-gray-500">No transactions yet</Text>
          </View>
        );

      case "txMore":
        return (
          <TouchableOpacity
            onPress={() => router.push("/portfolio/transactions" as never)}
            className="items-center py-3"
          >
            <Text className="text-sm font-medium text-primary-600">View all transactions →</Text>
          </TouchableOpacity>
        );

      default:
        return null;
    }
  };

  return (
    <SafeAreaView className="flex-1 bg-white" edges={["top"]}>
      <FlatList
        data={sections}
        keyExtractor={(_, i) => String(i)}
        renderItem={renderItem}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
      />
    </SafeAreaView>
  );
}

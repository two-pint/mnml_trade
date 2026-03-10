import { useEffect, useState } from "react";
import {
  View,
  Text,
  ActivityIndicator,
  ScrollView,
  TouchableOpacity,
} from "react-native";
import type {
  InstitutionalData,
  CongressionalTrade,
  InsiderTrade,
  InstitutionalHolding,
  SmartMoneyScore,
  OptionsFlowTrade,
} from "@repo/types";
import { stocksApi } from "@/lib/api";

type FlowFilter = "all" | "calls" | "puts";

function formatCompact(n: number): string {
  const abs = Math.abs(n);
  if (abs >= 1e9) return `${(n / 1e9).toFixed(1)}B`;
  if (abs >= 1e6) return `${(n / 1e6).toFixed(1)}M`;
  if (abs >= 1e3) return `${(n / 1e3).toFixed(0)}K`;
  return n.toLocaleString();
}

function formatCurrency(n: number | null): string {
  if (n == null) return "—";
  return `$${formatCompact(n)}`;
}

function formatDate(d: string | null): string {
  if (!d) return "—";
  try {
    return new Date(d).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  } catch {
    return d;
  }
}

function SentimentBadge({ sentiment }: { sentiment: string | null }) {
  if (!sentiment) return null;
  const lower = sentiment.toLowerCase();
  const cls =
    lower === "bullish" || lower === "buy" || lower.includes("purchase")
      ? "bg-green-100 text-green-800"
      : lower === "bearish" || lower === "sell" || lower.includes("sale")
        ? "bg-red-100 text-red-800"
        : "bg-gray-100 text-gray-600";
  return (
    <View className={`rounded-full px-2 py-0.5 ${cls}`}>
      <Text className="text-xs font-medium capitalize">{sentiment}</Text>
    </View>
  );
}

function StatCard({
  label,
  value,
  sub,
  valueColor,
}: {
  label: string;
  value: string;
  sub?: string;
  valueColor?: string;
}) {
  return (
    <View className="flex-1 items-center rounded-lg border border-gray-100 bg-gray-50 p-3">
      <Text className="text-[10px] text-gray-500">{label}</Text>
      <Text className={`mt-1 text-lg font-bold ${valueColor ?? "text-gray-900"}`}>
        {value}
      </Text>
      {sub && <Text className="mt-0.5 text-[10px] text-gray-400">{sub}</Text>}
    </View>
  );
}

function OptionsFlowSection({ trades }: { trades: OptionsFlowTrade[] }) {
  const [filter, setFilter] = useState<FlowFilter>("all");

  const filtered = trades.filter((t) => {
    if (filter === "all") return true;
    const type = t.type?.toLowerCase() ?? "";
    if (filter === "calls") return type.includes("call");
    return type.includes("put");
  });

  return (
    <View className="rounded-xl border border-gray-200 bg-white p-4">
      <View className="mb-3 flex-row items-center justify-between">
        <Text className="text-sm font-semibold text-gray-700">Options Flow</Text>
        <View className="flex-row gap-1">
          {(["all", "calls", "puts"] as const).map((f) => (
            <TouchableOpacity
              key={f}
              onPress={() => setFilter(f)}
              className={`rounded-lg px-2.5 py-1 ${
                filter === f ? "bg-primary-600" : "bg-gray-100"
              }`}
            >
              <Text
                className={`text-xs font-medium capitalize ${
                  filter === f ? "text-white" : "text-gray-600"
                }`}
              >
                {f}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>
      {filtered.length === 0 ? (
        <Text className="py-6 text-center text-sm text-gray-400">No options flow data</Text>
      ) : (
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          <View>
            {/* Header */}
            <View className="flex-row border-b border-gray-100 pb-2">
              <Text className="w-16 text-xs font-medium text-gray-500">Type</Text>
              <Text className="w-16 text-xs font-medium text-gray-500">Strike</Text>
              <Text className="w-20 text-xs font-medium text-gray-500">Expiry</Text>
              <Text className="w-20 text-right text-xs font-medium text-gray-500">Premium</Text>
              <Text className="w-14 text-right text-xs font-medium text-gray-500">Qty</Text>
              <Text className="w-20 text-center text-xs font-medium text-gray-500">Signal</Text>
            </View>
            {/* Rows */}
            {filtered.slice(0, 15).map((t, i) => {
              const isLarge = (t.premium ?? 0) >= 1_000_000;
              return (
                <View
                  key={i}
                  className={`flex-row items-center border-b border-gray-50 py-2 ${isLarge ? "bg-yellow-50" : ""}`}
                >
                  <Text className="w-16 text-xs font-medium text-gray-900">{t.type ?? "—"}</Text>
                  <Text className="w-16 text-xs text-gray-700">
                    {t.strike != null ? `$${t.strike}` : "—"}
                  </Text>
                  <Text className="w-20 text-xs text-gray-700">{t.expiry ?? "—"}</Text>
                  <Text className={`w-20 text-right text-xs font-medium ${isLarge ? "text-yellow-700" : "text-gray-900"}`}>
                    {formatCurrency(t.premium)}
                  </Text>
                  <Text className="w-14 text-right text-xs text-gray-700">
                    {t.quantity?.toLocaleString() ?? "—"}
                  </Text>
                  <View className="w-20 items-center">
                    <SentimentBadge sentiment={t.sentiment} />
                  </View>
                </View>
              );
            })}
          </View>
        </ScrollView>
      )}
    </View>
  );
}

function CongressionalSection({ trades }: { trades: CongressionalTrade[] | null }) {
  if (!trades || trades.length === 0) {
    return (
      <View className="rounded-xl border border-gray-200 bg-white p-4">
        <Text className="mb-2 text-sm font-semibold text-gray-700">Congressional Trading</Text>
        <Text className="py-4 text-center text-sm text-gray-400">No congressional trades found</Text>
      </View>
    );
  }

  return (
    <View className="rounded-xl border border-gray-200 bg-white p-4">
      <Text className="mb-3 text-sm font-semibold text-gray-700">Congressional Trading</Text>
      <View className="gap-2">
        {trades.slice(0, 8).map((t, i) => (
          <View key={i} className="rounded-lg border border-gray-50 bg-gray-50 p-3">
            <View className="flex-row items-center justify-between">
              <Text className="text-sm font-medium text-gray-900">
                {t.representative ?? "—"}
              </Text>
              <SentimentBadge sentiment={t.transaction_type} />
            </View>
            <View className="mt-1 flex-row items-center gap-2">
              <View
                className={`rounded-full px-2 py-0.5 ${
                  t.party === "Democrat"
                    ? "bg-blue-50"
                    : t.party === "Republican"
                      ? "bg-red-50"
                      : "bg-gray-100"
                }`}
              >
                <Text
                  className={`text-[10px] font-medium ${
                    t.party === "Democrat"
                      ? "text-blue-700"
                      : t.party === "Republican"
                        ? "text-red-700"
                        : "text-gray-600"
                  }`}
                >
                  {t.party ?? "—"}
                </Text>
              </View>
              <Text className="text-xs text-gray-500">{t.amount ?? "—"}</Text>
              <Text className="text-xs text-gray-400">{formatDate(t.date)}</Text>
            </View>
          </View>
        ))}
      </View>
      <Text className="mt-3 text-[10px] text-gray-400">
        Data from STOCK Act filings. Reported with a delay.
      </Text>
    </View>
  );
}

function InsiderSection({ trades }: { trades: InsiderTrade[] | null }) {
  if (!trades || trades.length === 0) {
    return (
      <View className="rounded-xl border border-gray-200 bg-white p-4">
        <Text className="mb-2 text-sm font-semibold text-gray-700">Insider Transactions</Text>
        <Text className="py-4 text-center text-sm text-gray-400">No insider trades found</Text>
      </View>
    );
  }

  return (
    <View className="rounded-xl border border-gray-200 bg-white p-4">
      <Text className="mb-3 text-sm font-semibold text-gray-700">Insider Transactions</Text>
      <View className="gap-2">
        {trades.slice(0, 8).map((t, i) => (
          <View key={i} className="rounded-lg border border-gray-50 bg-gray-50 p-3">
            <View className="flex-row items-center justify-between">
              <View className="flex-1">
                <Text className="text-sm font-medium text-gray-900">
                  {t.insider_name ?? "—"}
                </Text>
                <Text className="text-xs text-gray-500">{t.title ?? "—"}</Text>
              </View>
              <SentimentBadge sentiment={t.transaction_type} />
            </View>
            <View className="mt-1 flex-row gap-4">
              <Text className="text-xs text-gray-500">
                {t.shares?.toLocaleString() ?? "—"} shares
              </Text>
              <Text className="text-xs text-gray-500">{formatCurrency(t.value)}</Text>
              <Text className="text-xs text-gray-400">{formatDate(t.date)}</Text>
            </View>
          </View>
        ))}
      </View>
    </View>
  );
}

function HoldingsSection({ holdings }: { holdings: InstitutionalHolding[] | null }) {
  if (!holdings || holdings.length === 0) {
    return (
      <View className="rounded-xl border border-gray-200 bg-white p-4">
        <Text className="mb-2 text-sm font-semibold text-gray-700">Institutional Holdings</Text>
        <Text className="py-4 text-center text-sm text-gray-400">No holdings data available</Text>
      </View>
    );
  }

  return (
    <View className="rounded-xl border border-gray-200 bg-white p-4">
      <Text className="mb-3 text-sm font-semibold text-gray-700">Top Institutional Holders</Text>
      <View className="gap-2">
        {holdings.slice(0, 10).map((h, i) => (
          <View key={i} className="flex-row items-center justify-between border-b border-gray-50 py-2">
            <View className="flex-1">
              <Text className="text-sm font-medium text-gray-900" numberOfLines={1}>
                {h.holder ?? "—"}
              </Text>
              <Text className="text-xs text-gray-500">
                {h.shares?.toLocaleString() ?? "—"} shares · {formatCurrency(h.value)}
              </Text>
            </View>
            <Text
              className={`text-sm font-medium ${
                (h.change_percent ?? 0) > 0
                  ? "text-green-600"
                  : (h.change_percent ?? 0) < 0
                    ? "text-red-600"
                    : "text-gray-500"
              }`}
            >
              {h.change_percent != null
                ? `${h.change_percent > 0 ? "+" : ""}${h.change_percent.toFixed(1)}%`
                : "—"}
            </Text>
          </View>
        ))}
      </View>
    </View>
  );
}

export default function InstitutionalTab({ ticker }: { ticker: string }) {
  const [basicData, setBasicData] = useState<InstitutionalData | null>(null);
  const [congressional, setCongressional] = useState<CongressionalTrade[] | null>(null);
  const [insider, setInsider] = useState<InsiderTrade[] | null>(null);
  const [holdings, setHoldings] = useState<InstitutionalHolding[] | null>(null);
  const [smartMoney, setSmartMoney] = useState<SmartMoneyScore | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  useEffect(() => {
    if (!ticker) return;
    setLoading(true);
    setError(false);

    Promise.allSettled([
      stocksApi.getStockInstitutional(ticker).then(setBasicData),
      stocksApi.getCongressional(ticker).then((r) => setCongressional(r.trades)),
      stocksApi.getInsiderTrades(ticker).then((r) => setInsider(r.trades)),
      stocksApi.getHoldings(ticker).then((r) => setHoldings(r.holdings)),
      stocksApi.getSmartMoneyScore(ticker).then(setSmartMoney),
    ])
      .then((results) => {
        if (results.every((r) => r.status === "rejected")) setError(true);
      })
      .finally(() => setLoading(false));
  }, [ticker]);

  if (loading) {
    return (
      <View className="items-center py-12">
        <ActivityIndicator size="small" color="#4c6ef5" />
      </View>
    );
  }

  if (error) {
    return (
      <View className="items-center py-12">
        <Text className="text-gray-500">Institutional data unavailable</Text>
      </View>
    );
  }

  const flowCount = basicData?.options_flow?.length ?? 0;
  const bullishFlow =
    basicData?.options_flow?.filter((t) => t.sentiment?.toLowerCase() === "bullish").length ?? 0;
  const dpVolume = basicData?.dark_pool?.volume;

  return (
    <View className="gap-4 p-4">
      {/* Quick Stats */}
      <View className="flex-row gap-2">
        <StatCard
          label="Smart Money"
          value={smartMoney ? `${smartMoney.score}` : "—"}
          sub={smartMoney?.label ?? undefined}
          valueColor={
            smartMoney && smartMoney.score >= 60
              ? "text-green-600"
              : smartMoney && smartMoney.score < 40
                ? "text-red-600"
                : "text-gray-900"
          }
        />
        <StatCard
          label="Options Flow"
          value={`${flowCount}`}
          sub={`${bullishFlow} bullish`}
        />
        <StatCard
          label="Dark Pool"
          value={dpVolume != null ? formatCompact(dpVolume) : "—"}
        />
      </View>

      <OptionsFlowSection trades={basicData?.options_flow ?? []} />

      <CongressionalSection trades={congressional} />

      <InsiderSection trades={insider} />

      <HoldingsSection holdings={holdings} />

      <Text className="text-center text-[10px] text-gray-400">
        For informational purposes only. Not investment advice.
      </Text>
    </View>
  );
}

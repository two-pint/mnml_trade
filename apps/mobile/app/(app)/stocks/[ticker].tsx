"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  RefreshControl,
  useWindowDimensions,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useLocalSearchParams, useRouter } from "expo-router";
import type {
  AgentAnalysis,
  DailyOhlcv,
  IntradayOhlcv,
  StockOverview,
  TechnicalAnalysis,
  WatchlistItem,
} from "@repo/types";
import { ApiClientError } from "@repo/api-client";
import { stocksApi, engagementApi } from "@/lib/api";
import FundamentalTab from "@/components/FundamentalTab";
import EmotionalTab from "@/components/EmotionalTab";
import InstitutionalTab from "@/components/InstitutionalTab";

type Timeframe = "1D" | "1M" | "6M" | "1Y";

const TABS = [
  { id: "technical", label: "Technical" },
  { id: "fundamental", label: "Fundamental" },
  { id: "emotional", label: "Emotional" },
  { id: "institutional", label: "Institutional" },
] as const;

type ChartPoint = { date: string; open: number | null; high: number | null; low: number | null; close: number | null; volume: number | null };

function intradayToChartPoints(bars: IntradayOhlcv[]): ChartPoint[] {
  const ordered = [...bars].reverse();
  return ordered.map((b) => {
    const time =
      typeof b.datetime === "string" && b.datetime.length >= 16
        ? b.datetime.slice(11, 16)
        : b.datetime;
    return {
      date: time,
      open: b.open,
      high: b.high,
      low: b.low,
      close: b.close,
      volume: b.volume,
    };
  });
}

function filterByTimeframe(series: DailyOhlcv[], tf: Timeframe): ChartPoint[] {
  if (!series.length || tf === "1D") return [];
  const now = new Date();
  let cut: Date;
  switch (tf) {
    case "1M":
      cut = new Date(now);
      cut.setMonth(cut.getMonth() - 1);
      break;
    case "6M":
      cut = new Date(now);
      cut.setMonth(cut.getMonth() - 6);
      break;
    case "1Y":
      cut = new Date(now);
      cut.setFullYear(cut.getFullYear() - 1);
      break;
    default:
      return series.map((d) => ({ ...d, date: d.date }));
  }
  const cutStr = cut.toISOString().slice(0, 10);
  return series
    .filter((d) => d.date >= cutStr)
    .slice(-80)
    .map((d) => ({ ...d, date: d.date }));
}

export default function StockDetailScreen() {
  const { ticker: rawTicker } = useLocalSearchParams<{ ticker: string }>();
  const ticker = rawTicker ? decodeURIComponent(rawTicker) : "";
  const router = useRouter();
  const { width } = useWindowDimensions();

  const [overview, setOverview] = useState<StockOverview | null>(null);
  const [technical, setTechnical] = useState<TechnicalAnalysis | null>(null);
  const [daily, setDaily] = useState<DailyOhlcv[]>([]);
  const [intraday, setIntraday] = useState<IntradayOhlcv[]>([]);
  const [tab, setTab] = useState<string>("technical");
  const [timeframe, setTimeframe] = useState<Timeframe>("1M");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [inWatchlist, setInWatchlist] = useState(false);
  const [watchlistLoading, setWatchlistLoading] = useState(false);
  const [agentAnalysis, setAgentAnalysis] = useState<AgentAnalysis | null>(null);
  const [agentAnalysisLoading, setAgentAnalysisLoading] = useState(false);
  const [agentAnalysisError, setAgentAnalysisError] = useState<"unavailable" | "forbidden" | null>(null);

  const load = useCallback(() => {
    if (!ticker) return;
    setError(null);
    Promise.all([
      stocksApi.getStock(ticker),
      stocksApi.getStockTechnical(ticker).catch(() => null),
      stocksApi.getStockDaily(ticker).catch(() => []),
      stocksApi.getStockIntraday(ticker, { interval: "1min", days: 1 }).catch(() => []),
    ])
      .then(([ov, tech, d, intra]) => {
        setOverview(ov);
        setTechnical(tech ?? null);
        setDaily(Array.isArray(d) ? d : []);
        setIntraday(Array.isArray(intra) ? intra : []);
      })
      .catch(() => setError("Failed to load"))
      .finally(() => {
        setLoading(false);
        setRefreshing(false);
      });
  }, [ticker]);

  useEffect(() => {
    if (ticker) {
      setLoading(true);
      load();
    }
  }, [ticker, load]);

  useEffect(() => {
    if (!ticker || loading) return;
    const interval = setInterval(() => {
      stocksApi
        .getStock(ticker)
        .then(setOverview)
        .catch(() => {});
    }, 15_000);
    return () => clearInterval(interval);
  }, [ticker, loading]);

  useEffect(() => {
    if (!ticker) return;
    setAgentAnalysisError(null);
    setAgentAnalysisLoading(true);
    stocksApi
      .getAgentAnalysis(ticker)
      .then(setAgentAnalysis)
      .catch((e: unknown) => {
        if (e instanceof ApiClientError && e.status === 403) {
          setAgentAnalysisError("forbidden");
        } else {
          setAgentAnalysisError("unavailable");
        }
      })
      .finally(() => setAgentAnalysisLoading(false));
  }, [ticker]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    load();
  }, [load]);

  useEffect(() => {
    if (!ticker) return;
    engagementApi
      .listWatchlist()
      .then(({ data }) => {
        setInWatchlist(data.some((w: WatchlistItem) => w.ticker === ticker.toUpperCase()));
      })
      .catch(() => {});
  }, [ticker]);

  const toggleWatchlist = async () => {
    setWatchlistLoading(true);
    try {
      if (inWatchlist) {
        await engagementApi.removeFromWatchlist(ticker);
        setInWatchlist(false);
      } else {
        await engagementApi.addToWatchlist(ticker);
        setInWatchlist(true);
      }
    } catch {
      // ignore
    } finally {
      setWatchlistLoading(false);
    }
  };

  const chartData = useMemo((): ChartPoint[] => {
    if (timeframe === "1D") return intradayToChartPoints(intraday);
    return filterByTimeframe(daily, timeframe);
  }, [daily, intraday, timeframe]);

  if (!ticker) {
    return (
      <SafeAreaView className="flex-1 bg-white">
        <View className="p-6">
          <Text className="text-gray-500">Missing ticker</Text>
        </View>
      </SafeAreaView>
    );
  }

  if (error && !overview) {
    return (
      <SafeAreaView className="flex-1 bg-white">
        <View className="flex-1 items-center justify-center p-6">
          <View className="rounded-lg border border-red-200 bg-red-50 p-4">
            <Text className="text-red-600">{error}</Text>
            <View className="mt-4 flex-row gap-3">
              <TouchableOpacity
                onPress={() => {
                  setError(null);
                  setLoading(true);
                  load();
                }}
                className="rounded-lg bg-primary-600 px-4 py-2"
              >
                <Text className="font-medium text-white">Retry</Text>
              </TouchableOpacity>
              <TouchableOpacity
                onPress={() => router.back()}
                className="rounded-lg bg-gray-200 px-4 py-2"
              >
                <Text className="font-medium text-gray-700">Go back</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </SafeAreaView>
    );
  }

  const changeNum = overview?.change ?? 0;
  const isPositive = changeNum >= 0;

  return (
    <SafeAreaView className="flex-1 bg-white" edges={["top"]}>
      <ScrollView
        className="flex-1"
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
      >
        <View className="border-b border-gray-200 px-4 py-3">
          <TouchableOpacity onPress={() => router.back()} className="mb-2">
            <Text className="text-primary-600">← Back</Text>
          </TouchableOpacity>
          {loading && !overview ? (
            <ActivityIndicator size="small" color="#4c6ef5" />
          ) : overview ? (
            <>
              <View className="flex-row items-center justify-between">
                <Text className="text-2xl font-bold text-gray-900">{overview.ticker}</Text>
                <View className="flex-row items-center gap-2">
                  <TouchableOpacity
                    onPress={toggleWatchlist}
                    disabled={watchlistLoading}
                    className={`rounded-lg border px-3 py-2 ${
                      inWatchlist
                        ? "border-amber-300 bg-amber-50"
                        : "border-gray-300"
                    }`}
                    style={{ opacity: watchlistLoading ? 0.5 : 1 }}
                  >
                    <Text className={`text-base ${inWatchlist ? "text-amber-600" : "text-gray-400"}`}>
                      {inWatchlist ? "★" : "☆"}
                    </Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    onPress={() => router.push(`/trade?ticker=${encodeURIComponent(overview.ticker)}` as never)}
                    className="rounded-lg bg-primary-600 px-4 py-2"
                  >
                    <Text className="font-semibold text-white">Trade</Text>
                  </TouchableOpacity>
                </View>
              </View>
              <View className="mt-2 flex-row items-baseline gap-3">
                <Text className="text-xl font-semibold text-gray-900">
                  ${overview.price != null ? overview.price.toFixed(2) : "—"}
                </Text>
                <Text
                  className={
                    isPositive ? "text-green-600" : "text-red-600"
                  }
                >
                  {isPositive ? "+" : ""}
                  {overview.change != null ? overview.change.toFixed(2) : "—"}{" "}
                  ({overview.change_percent ?? "—"})
                </Text>
              </View>
              <View className="mt-3 flex-row gap-4">
                <Text className="text-sm text-gray-500">
                  Vol: {overview.volume != null ? overview.volume.toLocaleString() : "—"}
                </Text>
                <Text className="text-sm text-gray-500">
                  O: {overview.open != null ? overview.open.toFixed(2) : "—"} H:{" "}
                  {overview.high != null ? overview.high.toFixed(2) : "—"} L:{" "}
                  {overview.low != null ? overview.low.toFixed(2) : "—"}
                </Text>
              </View>
              {overview.recommendation && (
                <View className="mt-3">
                  <View className="flex-row items-center gap-2">
                    <View
                      className={`rounded-full px-3 py-1 ${
                        overview.recommendation === "Strong Buy" || overview.recommendation === "Buy"
                          ? "bg-green-100"
                          : overview.recommendation === "Sell" || overview.recommendation === "Strong Sell"
                            ? "bg-red-100"
                            : "bg-gray-100"
                      }`}
                    >
                      <Text
                        className={`text-sm font-bold ${
                          overview.recommendation === "Strong Buy" || overview.recommendation === "Buy"
                            ? "text-green-800"
                            : overview.recommendation === "Sell" || overview.recommendation === "Strong Sell"
                              ? "text-red-800"
                              : "text-gray-700"
                        }`}
                      >
                        {overview.recommendation}
                      </Text>
                    </View>
                    {overview.recommendation_score != null && (
                      <Text className="text-sm text-gray-500">
                        {overview.recommendation_score}/100
                      </Text>
                    )}
                    {overview.confidence != null && (
                      <Text className="text-xs text-gray-400">
                        {overview.confidence}% conf
                      </Text>
                    )}
                  </View>
                  {overview.sub_scores && (
                    <View className="mt-2 flex-row gap-2">
                      {([
                        { key: "technical" as const, label: "Tech" },
                        { key: "fundamental" as const, label: "Fund" },
                        { key: "sentiment" as const, label: "Sent" },
                        { key: "institutional" as const, label: "Inst" },
                      ] as const).map(({ key, label }) => {
                        const val = overview.sub_scores?.[key];
                        const barColor =
                          val != null && val >= 60
                            ? "bg-green-500"
                            : val != null && val < 40
                              ? "bg-red-500"
                              : "bg-gray-400";
                        return (
                          <View key={key} className="flex-1">
                            <View className="flex-row justify-between">
                              <Text className="text-[10px] text-gray-500">{label}</Text>
                              <Text className="text-[10px] font-medium text-gray-700">
                                {val ?? "—"}
                              </Text>
                            </View>
                            <View className="mt-0.5 h-1 w-full rounded-full bg-gray-200">
                              {val != null && (
                                <View
                                  className={`h-full rounded-full ${barColor}`}
                                  style={{ width: `${val}%` }}
                                />
                              )}
                            </View>
                          </View>
                        );
                      })}
                    </View>
                  )}
                </View>
              )}
            </>
          ) : null}
        </View>

        {/* AI Analysis */}
        <View className="border-t border-gray-100 px-4 py-4">
          <Text className="text-sm font-semibold text-gray-700">AI Analysis</Text>
          {agentAnalysisLoading ? (
            <View className="mt-4">
              <ActivityIndicator size="small" color="#4c6ef5" />
            </View>
          ) : agentAnalysisError === "forbidden" ? (
            <View className="mt-4 rounded-lg border border-amber-200 bg-amber-50 p-4">
              <Text className="text-sm text-amber-800">
                Add your API key in Settings to enable AI analysis.
              </Text>
              <TouchableOpacity
                onPress={() => router.push("/(tabs)/profile" as never)}
                className="mt-2"
              >
                <Text className="text-sm font-medium text-primary-600">Go to Settings →</Text>
              </TouchableOpacity>
            </View>
          ) : agentAnalysisError === "unavailable" ? (
            <Text className="mt-4 text-sm text-gray-500">Analysis unavailable. Try again later.</Text>
          ) : agentAnalysis ? (
            <>
              <Text className="mt-1 text-xs text-gray-500">For research only; not investment advice.</Text>
              <Text className="mt-4 text-gray-900">{agentAnalysis.summary}</Text>
              {agentAnalysis.consideration && (
                <View
                  className={`mt-4 self-start rounded-full px-3 py-1 ${
                    agentAnalysis.consideration === "Strong buy" || agentAnalysis.consideration === "Worth a look"
                      ? "bg-green-100"
                      : agentAnalysis.consideration === "Strong sell" || agentAnalysis.consideration === "Avoid"
                        ? "bg-red-100"
                        : "bg-gray-100"
                  }`}
                >
                  <Text
                    className={`text-sm font-medium ${
                      agentAnalysis.consideration === "Strong buy" || agentAnalysis.consideration === "Worth a look"
                        ? "text-green-800"
                        : agentAnalysis.consideration === "Strong sell" || agentAnalysis.consideration === "Avoid"
                          ? "text-red-800"
                          : "text-gray-700"
                    }`}
                  >
                    {agentAnalysis.consideration}
                  </Text>
                </View>
              )}
              {(agentAnalysis.bull_points?.length ?? 0) > 0 && (
                <View className="mt-4">
                  <Text className="text-xs font-medium uppercase text-gray-500">Bull points</Text>
                  {agentAnalysis.bull_points?.map((p, i) => (
                    <Text key={i} className="mt-1 text-sm text-gray-700">• {p}</Text>
                  ))}
                </View>
              )}
              {(agentAnalysis.bear_points?.length ?? 0) > 0 && (
                <View className="mt-3">
                  <Text className="text-xs font-medium uppercase text-gray-500">Bear points</Text>
                  {agentAnalysis.bear_points?.map((p, i) => (
                    <Text key={i} className="mt-1 text-sm text-gray-700">• {p}</Text>
                  ))}
                </View>
              )}
            </>
          ) : null}
        </View>

        {/* Tabs */}
        <View className="flex-row border-b border-gray-200 px-2">
          {TABS.map((t) => (
            <TouchableOpacity
              key={t.id}
              onPress={() => setTab(t.id)}
              className={`border-b-2 px-4 py-3 ${
                tab === t.id
                  ? "border-primary-600"
                  : "border-transparent"
              }`}
            >
              <Text
                className={
                  tab === t.id
                    ? "font-semibold text-primary-600"
                    : "text-gray-500"
                }
              >
                {t.label}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        {tab === "technical" && (
          <View className="p-4">
            {/* Timeframe */}
            <View className="mb-4 flex-row flex-wrap gap-2">
              {(["1D", "1M", "6M", "1Y"] as const).map((tf) => (
                <TouchableOpacity
                  key={tf}
                  onPress={() => setTimeframe(tf)}
                  className={`rounded-lg px-3 py-1.5 ${
                    timeframe === tf ? "bg-primary-600" : "bg-gray-100"
                  }`}
                >
                  <Text
                    className={
                      timeframe === tf
                        ? "font-medium text-white"
                        : "text-gray-700"
                    }
                  >
                    {tf}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            {/* Simple chart placeholder (line of closes) */}
            {chartData.length > 0 && (
              <View className="mb-6 h-40 rounded-lg border border-gray-200 bg-gray-50 p-2">
                <Text className="mb-2 text-xs font-medium text-gray-500">
                  Price (close)
                </Text>
                <ScrollView horizontal showsHorizontalScrollIndicator={false}>
                  <View className="flex-row items-end gap-0.5" style={{ minWidth: width - 48 }}>
                    {chartData.slice(-60).map((d, i) => {
                      const closes = chartData.map((x) => x.close ?? 0).filter(Boolean);
                      const min = Math.min(...closes);
                      const max = Math.max(...closes) || 1;
                      const h = ((d.close ?? 0) - min) / (max - min || 1) * 120;
                      return (
                        <View
                          key={`${d.date}-${i}`}
                          className="w-1 rounded-sm bg-primary-500"
                          style={{ height: Math.max(2, h) }}
                        />
                      );
                    })}
                  </View>
                </ScrollView>
              </View>
            )}

            {/* Score + Indicators */}
            {technical ? (
              <>
                <View className="mb-4 flex-row items-center gap-3">
                  <Text className="text-sm text-gray-500">Score</Text>
                  <Text className="text-2xl font-bold text-gray-900">
                    {technical.score}
                  </Text>
                  <View
                    className={`rounded-full px-2 py-0.5 ${
                      technical.signal === "bullish"
                        ? "bg-green-100"
                        : technical.signal === "bearish"
                          ? "bg-red-100"
                          : "bg-gray-100"
                    }`}
                  >
                    <Text
                      className={`text-sm font-medium ${
                        technical.signal === "bullish"
                          ? "text-green-800"
                          : technical.signal === "bearish"
                            ? "text-red-800"
                            : "text-gray-700"
                      }`}
                    >
                      {technical.signal}
                    </Text>
                  </View>
                </View>
                <View className="rounded-lg border border-gray-200 bg-gray-50 p-4">
                  <Text className="mb-3 font-semibold text-gray-700">
                    Indicators
                  </Text>
                  {technical.indicators?.rsi && (
                    <View className="flex-row justify-between py-2">
                      <Text className="text-gray-600">RSI</Text>
                      <Text className="font-medium text-gray-900">
                        {typeof technical.indicators.rsi.value === "number"
                          ? technical.indicators.rsi.value.toFixed(2)
                          : "—"}
                      </Text>
                    </View>
                  )}
                  {technical.indicators?.sma_20 && (
                    <View className="flex-row justify-between py-2">
                      <Text className="text-gray-600">SMA 20</Text>
                      <Text className="font-medium text-gray-900">
                        {typeof technical.indicators.sma_20.value === "number"
                          ? technical.indicators.sma_20.value.toFixed(2)
                          : "—"}
                      </Text>
                    </View>
                  )}
                  {technical.indicators?.sma_50 && (
                    <View className="flex-row justify-between py-2">
                      <Text className="text-gray-600">SMA 50</Text>
                      <Text className="font-medium text-gray-900">
                        {typeof technical.indicators.sma_50.value === "number"
                          ? technical.indicators.sma_50.value.toFixed(2)
                          : "—"}
                      </Text>
                    </View>
                  )}
                  {technical.indicators?.sma_200 && (
                    <View className="flex-row justify-between py-2">
                      <Text className="text-gray-600">SMA 200</Text>
                      <Text className="font-medium text-gray-900">
                        {typeof technical.indicators.sma_200.value === "number"
                          ? technical.indicators.sma_200.value.toFixed(2)
                          : "—"}
                      </Text>
                    </View>
                  )}
                  {technical.support_resistance && (
                    <View className="mt-3 border-t border-gray-200 pt-3">
                      <Text className="text-xs text-gray-500">
                        Support: {technical.support_resistance.support?.toFixed(2) ?? "—"} |
                        Resistance: {technical.support_resistance.resistance?.toFixed(2) ?? "—"}
                      </Text>
                    </View>
                  )}
                </View>
              </>
            ) : (
              loading && <ActivityIndicator size="small" color="#4c6ef5" />
            )}
          </View>
        )}

        {tab === "fundamental" && <FundamentalTab ticker={ticker} />}
        {tab === "emotional" && <EmotionalTab ticker={ticker} />}
        {tab === "institutional" && <InstitutionalTab ticker={ticker} />}
      </ScrollView>
    </SafeAreaView>
  );
}

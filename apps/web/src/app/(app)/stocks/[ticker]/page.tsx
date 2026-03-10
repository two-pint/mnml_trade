"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useParams, useSearchParams } from "next/navigation";
import Link from "next/link";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  ComposedChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import type { DailyOhlcv, StockOverview, TechnicalAnalysis } from "@repo/types";
import { stocksApi } from "@/lib/api";
import FundamentalTab from "@/components/fundamental-tab";
import EmotionalTab from "@/components/emotional-tab";
import InstitutionalTab from "@/components/institutional-tab";

type Timeframe = "1D" | "1M" | "6M" | "1Y";

const TABS = [
  { id: "technical", label: "Technical" },
  { id: "fundamental", label: "Fundamental" },
  { id: "emotional", label: "Emotional" },
  { id: "institutional", label: "Institutional" },
] as const;

function filterByTimeframe(series: DailyOhlcv[], tf: Timeframe): DailyOhlcv[] {
  if (!series.length) return [];
  const now = new Date();
  let cut: Date;
  switch (tf) {
    case "1D":
      cut = new Date(now);
      cut.setDate(cut.getDate() - 1);
      break;
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
      return series;
  }
  const cutStr = cut.toISOString().slice(0, 10);
  return series.filter((d) => d.date >= cutStr).slice(-100);
}

function IndicatorRow({
  name,
  value,
  interpretation,
}: {
  name: string;
  value: string | number | number[] | null;
  interpretation?: "bullish" | "bearish" | "neutral";
}) {
  const color =
    interpretation === "bullish"
      ? "text-bullish"
      : interpretation === "bearish"
        ? "text-bearish"
        : "text-gray-600";
  const val =
    value != null
      ? Array.isArray(value)
        ? (value as number[]).map((n) => n?.toFixed(2) ?? "—").join(", ")
        : typeof value === "number"
          ? value.toFixed(2)
          : String(value)
      : "—";
  return (
    <div className="flex justify-between py-2 text-sm">
      <span className="font-medium text-gray-700">{name}</span>
      <span className={color}>
        {val}
        {interpretation && (
          <span className="ml-2 text-xs capitalize">({interpretation})</span>
        )}
      </span>
    </div>
  );
}

export default function StockPage() {
  const params = useParams();
  const searchParams = useSearchParams();
  const ticker = decodeURIComponent((params.ticker as string) ?? "");
  const tab = (searchParams.get("tab") || "technical") as string;

  const [overview, setOverview] = useState<StockOverview | null>(null);
  const [technical, setTechnical] = useState<TechnicalAnalysis | null>(null);
  const [daily, setDaily] = useState<DailyOhlcv[]>([]);
  const [overviewLoading, setOverviewLoading] = useState(true);
  const [technicalLoading, setTechnicalLoading] = useState(false);
  const [dailyLoading, setDailyLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [timeframe, setTimeframe] = useState<Timeframe>("1M");

  const setTab = useCallback(
    (id: string) => {
      const next = new URLSearchParams(searchParams.toString());
      next.set("tab", id);
      return `?${next.toString()}`;
    },
    [searchParams],
  );

  useEffect(() => {
    if (!ticker) return;
    setError(null);
    setOverviewLoading(true);
    stocksApi
      .getStock(ticker)
      .then(setOverview)
      .catch(() => setError("Failed to load stock"))
      .finally(() => setOverviewLoading(false));
  }, [ticker]);

  useEffect(() => {
    if (!ticker || tab !== "technical") return;
    setTechnicalLoading(true);
    stocksApi
      .getStockTechnical(ticker)
      .then(setTechnical)
      .catch(() => {})
      .finally(() => setTechnicalLoading(false));
  }, [ticker, tab]);

  useEffect(() => {
    if (!ticker || tab !== "technical") return;
    setDailyLoading(true);
    stocksApi
      .getStockDaily(ticker)
      .then(setDaily)
      .catch(() => setDaily([]))
      .finally(() => setDailyLoading(false));
  }, [ticker, tab]);

  const chartData = useMemo(
    () => filterByTimeframe(daily, timeframe),
    [daily, timeframe],
  );

  const changeNum = overview?.change ?? 0;
  const isPositive = changeNum >= 0;
  const isNegative = changeNum < 0;

  if (error && !overviewLoading) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-8">
        <p className="text-bearish">{error}</p>
        <Link href="/dashboard" className="mt-4 inline-block text-primary-600 hover:underline">
          Back to dashboard
        </Link>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-4xl px-4 py-6 sm:px-6">
      <Link
        href="/dashboard"
        className="mb-4 inline-block text-sm text-gray-500 hover:text-gray-900"
      >
        ← Dashboard
      </Link>

      {/* Overview */}
      <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        {overviewLoading ? (
          <div className="h-24 animate-pulse rounded bg-gray-100" />
        ) : overview ? (
          <>
            <h1 className="text-2xl font-bold text-gray-900">{overview.ticker}</h1>
            <div className="mt-4 flex flex-wrap items-baseline gap-6">
              <span className="text-3xl font-semibold text-gray-900">
                ${overview.price != null ? overview.price.toFixed(2) : "—"}
              </span>
              <span
                className={
                  isPositive
                    ? "text-bullish"
                    : isNegative
                      ? "text-bearish"
                      : "text-gray-500"
                }
              >
                {isPositive ? "+" : ""}
                {overview.change != null ? overview.change.toFixed(2) : "—"}{" "}
                ({overview.change_percent ?? "—"})
              </span>
            </div>
            <dl className="mt-4 grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
              <div>
                <dt className="text-gray-500">Volume</dt>
                <dd className="font-medium">
                  {overview.volume != null
                    ? overview.volume.toLocaleString()
                    : "—"}
                </dd>
              </div>
              <div>
                <dt className="text-gray-500">Open</dt>
                <dd className="font-medium">
                  {overview.open != null ? `$${overview.open.toFixed(2)}` : "—"}
                </dd>
              </div>
              <div>
                <dt className="text-gray-500">High</dt>
                <dd className="font-medium">
                  {overview.high != null ? `$${overview.high.toFixed(2)}` : "—"}
                </dd>
              </div>
              <div>
                <dt className="text-gray-500">Low</dt>
                <dd className="font-medium">
                  {overview.low != null ? `$${overview.low.toFixed(2)}` : "—"}
                </dd>
              </div>
            </dl>
            {overview.recommendation && (
              <div className="mt-4 space-y-3">
                <div className="flex flex-wrap items-center gap-3">
                  <span
                    className={`rounded-full px-4 py-1.5 text-sm font-bold ${
                      overview.recommendation === "Strong Buy" || overview.recommendation === "Buy"
                        ? "bg-bullish-light text-bullish-dark"
                        : overview.recommendation === "Sell" || overview.recommendation === "Strong Sell"
                          ? "bg-bearish-light text-bearish-dark"
                          : "bg-gray-100 text-gray-700"
                    }`}
                  >
                    {overview.recommendation}
                  </span>
                  {overview.recommendation_score != null && (
                    <span className="text-sm font-medium text-gray-600">
                      Score: {overview.recommendation_score}/100
                    </span>
                  )}
                  {overview.confidence != null && (
                    <span className="text-sm text-gray-400">
                      {overview.confidence}% confidence
                    </span>
                  )}
                </div>
                {overview.sub_scores && (
                  <div className="flex flex-wrap gap-3">
                    {(
                      [
                        { key: "technical" as const, label: "Technical", weight: "30%" },
                        { key: "fundamental" as const, label: "Fundamental", weight: "30%" },
                        { key: "sentiment" as const, label: "Sentiment", weight: "20%" },
                        { key: "institutional" as const, label: "Institutional", weight: "20%" },
                      ] as const
                    ).map(({ key, label, weight }) => {
                      const val = overview.sub_scores?.[key];
                      const barColor =
                        val != null && val >= 60
                          ? "bg-bullish"
                          : val != null && val < 40
                            ? "bg-bearish"
                            : "bg-gray-400";
                      return (
                        <div key={key} className="flex-1 min-w-[100px]">
                          <div className="flex items-baseline justify-between text-xs">
                            <span className="text-gray-500">{label}</span>
                            <span className="font-medium text-gray-700">
                              {val != null ? val : "—"}
                            </span>
                          </div>
                          <div className="mt-1 h-1.5 w-full rounded-full bg-gray-100">
                            {val != null && (
                              <div
                                className={`h-full rounded-full ${barColor}`}
                                style={{ width: `${val}%` }}
                              />
                            )}
                          </div>
                          <p className="mt-0.5 text-[10px] text-gray-400">{weight}</p>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            )}
            <p className="mt-2 text-xs text-gray-400">
              Market cap & 52w range coming soon
            </p>
          </>
        ) : null}
      </section>

      {/* Tabs */}
      <div className="mt-6 border-b border-gray-200">
        <nav className="flex gap-6" aria-label="Tabs">
          {TABS.map((t) => (
            <Link
              key={t.id}
              href={setTab(t.id)}
              className={`border-b-2 py-3 text-sm font-medium ${
                tab === t.id
                  ? "border-primary-600 text-primary-600"
                  : "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
              }`}
            >
              {t.label}
            </Link>
          ))}
        </nav>
      </div>

      {/* Tab content */}
      {tab === "technical" && (
        <section className="mt-6 space-y-6">
          {/* Timeframe + Chart */}
          <div className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
            <div className="mb-4 flex flex-wrap gap-2">
              {(["1D", "1M", "6M", "1Y"] as const).map((tf) => (
                <button
                  key={tf}
                  type="button"
                  onClick={() => setTimeframe(tf)}
                  className={`rounded-lg px-3 py-1.5 text-sm font-medium ${
                    timeframe === tf
                      ? "bg-primary-600 text-white"
                      : "bg-gray-100 text-gray-700 hover:bg-gray-200"
                  }`}
                >
                  {tf}
                </button>
              ))}
            </div>
            {dailyLoading ? (
              <div className="h-64 animate-pulse rounded bg-gray-100" />
            ) : chartData.length > 0 ? (
              <div className="h-64 w-full">
                <ResponsiveContainer width="100%" height="100%">
                  <ComposedChart data={chartData} margin={{ top: 8, right: 8, left: 8, bottom: 8 }}>
                    <defs>
                      <linearGradient id="priceFill" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor="var(--color-primary-500)" stopOpacity={0.3} />
                        <stop offset="100%" stopColor="var(--color-primary-500)" stopOpacity={0} />
                      </linearGradient>
                    </defs>
                    <XAxis dataKey="date" tick={{ fontSize: 10 }} />
                    <YAxis yAxisId="price" orientation="right" tick={{ fontSize: 10 }} width={50} />
                    <YAxis yAxisId="vol" orientation="left" tick={{ fontSize: 10 }} width={40} hide />
                    <Tooltip
                      formatter={(value: number) => (value != null ? value.toFixed(2) : "")}
                      labelFormatter={(label) => label}
                    />
                    <Area
                      yAxisId="price"
                      type="monotone"
                      dataKey="close"
                      stroke="var(--color-primary-600)"
                      fill="url(#priceFill)"
                      strokeWidth={2}
                    />
                    <Bar yAxisId="vol" dataKey="volume" fill="#94a3b8" radius={[2, 2, 0, 0]} />
                  </ComposedChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <div className="flex h-64 items-center justify-center text-gray-500">
                No chart data
              </div>
            )}
          </div>

          {/* Score + Indicators */}
          <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
            {technicalLoading ? (
              <div className="h-32 animate-pulse rounded bg-gray-100" />
            ) : technical ? (
              <>
                <div className="mb-6 flex flex-wrap items-center gap-4">
                  <div className="flex items-baseline gap-2">
                    <span className="text-sm text-gray-500">Technical score</span>
                    <span className="text-2xl font-bold text-gray-900">{technical.score}</span>
                    <span
                      className={`rounded-full px-2 py-0.5 text-sm font-medium ${
                        technical.signal === "bullish"
                          ? "bg-bullish-light text-bullish-dark"
                          : technical.signal === "bearish"
                            ? "bg-bearish-light text-bearish-dark"
                            : "bg-gray-100 text-gray-700"
                      }`}
                    >
                      {technical.signal}
                    </span>
                  </div>
                </div>
                <div className="grid gap-4 sm:grid-cols-2">
                  <div className="rounded-lg border border-gray-100 bg-gray-50/50 p-4">
                    <h3 className="mb-3 text-sm font-semibold text-gray-700">Indicators</h3>
                    {technical.indicators?.rsi && (
                      <IndicatorRow
                        name="RSI"
                        value={
                          typeof technical.indicators.rsi.value === "number"
                            ? technical.indicators.rsi.value
                            : Array.isArray(technical.indicators.rsi.value)
                              ? technical.indicators.rsi.value[0]
                              : null
                        }
                        interpretation={
                          (typeof technical.indicators.rsi.value === "number"
                            ? technical.indicators.rsi.value < 30
                              ? "bullish"
                              : technical.indicators.rsi.value > 70
                                ? "bearish"
                                : "neutral"
                            : "neutral") as "bullish" | "bearish" | "neutral"
                        }
                      />
                    )}
                    {technical.indicators?.sma_20 && (
                      <IndicatorRow
                        name="SMA 20"
                        value={
                          typeof technical.indicators.sma_20.value === "number"
                            ? technical.indicators.sma_20.value
                            : null
                        }
                      />
                    )}
                    {technical.indicators?.sma_50 && (
                      <IndicatorRow
                        name="SMA 50"
                        value={
                          typeof technical.indicators.sma_50.value === "number"
                            ? technical.indicators.sma_50.value
                            : null
                        }
                      />
                    )}
                    {technical.indicators?.sma_200 && (
                      <IndicatorRow
                        name="SMA 200"
                        value={
                          typeof technical.indicators.sma_200.value === "number"
                            ? technical.indicators.sma_200.value
                            : null
                        }
                      />
                    )}
                    {technical.indicators?.macd && (
                      <IndicatorRow
                        name="MACD"
                        value={
                          Array.isArray(technical.indicators.macd.value)
                            ? technical.indicators.macd.value
                            : technical.indicators.macd.value
                        }
                      />
                    )}
                    {technical.indicators?.adx && (
                      <IndicatorRow
                        name="ADX"
                        value={
                          typeof technical.indicators.adx.value === "number"
                            ? technical.indicators.adx.value
                            : null
                        }
                      />
                    )}
                  </div>
                  <div className="rounded-lg border border-gray-100 bg-gray-50/50 p-4">
                    <h3 className="mb-3 text-sm font-semibold text-gray-700">Support / Resistance</h3>
                    <p className="text-sm text-gray-600">
                      Support: {technical.support_resistance?.support?.toFixed(2) ?? "—"}
                    </p>
                    <p className="mt-1 text-sm text-gray-600">
                      Resistance: {technical.support_resistance?.resistance?.toFixed(2) ?? "—"}
                    </p>
                  </div>
                </div>
              </>
            ) : null}
          </div>
        </section>
      )}

      {tab === "fundamental" && <FundamentalTab ticker={ticker} />}

      {tab === "emotional" && <EmotionalTab ticker={ticker} tabSetter={setTab} />}

      {tab === "institutional" && <InstitutionalTab ticker={ticker} />}
    </div>
  );
}

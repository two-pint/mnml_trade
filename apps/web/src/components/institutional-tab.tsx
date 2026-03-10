"use client";

import { useEffect, useState } from "react";
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
    return new Date(d).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
  } catch {
    return d;
  }
}

function SentimentBadge({ sentiment }: { sentiment: string | null }) {
  if (!sentiment) return null;
  const lower = sentiment.toLowerCase();
  const cls =
    lower === "bullish" || lower === "buy"
      ? "bg-bullish-light text-bullish-dark"
      : lower === "bearish" || lower === "sell"
        ? "bg-bearish-light text-bearish-dark"
        : "bg-gray-100 text-gray-600";
  return (
    <span className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium capitalize ${cls}`}>
      {sentiment}
    </span>
  );
}

function ScoreRing({ score, size = 80 }: { score: number; size?: number }) {
  const radius = (size - 8) / 2;
  const circumference = 2 * Math.PI * radius;
  const progress = (score / 100) * circumference;
  const color =
    score >= 70 ? "text-bullish" : score >= 40 ? "text-yellow-500" : "text-bearish";
  const strokeColor =
    score >= 70
      ? "var(--color-bullish)"
      : score >= 40
        ? "#eab308"
        : "var(--color-bearish)";

  return (
    <div className="relative inline-flex items-center justify-center" style={{ width: size, height: size }}>
      <svg width={size} height={size} className="-rotate-90">
        <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke="#e5e7eb" strokeWidth="6" />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={strokeColor}
          strokeWidth="6"
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={circumference - progress}
        />
      </svg>
      <span className={`absolute text-lg font-bold ${color}`}>{score}</span>
    </div>
  );
}

function QuickStatsCards({
  smartMoney,
  basicData,
}: {
  smartMoney: SmartMoneyScore | null;
  basicData: InstitutionalData | null;
}) {
  const flowCount = basicData?.options_flow?.length ?? 0;
  const bullishFlow = basicData?.options_flow?.filter(
    (t) => t.sentiment?.toLowerCase() === "bullish",
  ).length ?? 0;
  const bearishFlow = flowCount - bullishFlow;
  const dpVolume = basicData?.dark_pool?.volume;
  const dpNet = basicData?.dark_pool?.net_buy_sell;

  return (
    <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
      <div className="rounded-lg border border-gray-100 bg-gray-50/50 p-4 text-center">
        <p className="text-xs text-gray-500">Smart Money Score</p>
        {smartMoney ? (
          <div className="mt-2 flex flex-col items-center">
            <ScoreRing score={smartMoney.score} size={64} />
            <p className="mt-1 text-xs font-medium text-gray-600">{smartMoney.label}</p>
          </div>
        ) : (
          <p className="mt-3 text-lg font-semibold text-gray-400">—</p>
        )}
      </div>
      <div className="rounded-lg border border-gray-100 bg-gray-50/50 p-4 text-center">
        <p className="text-xs text-gray-500">Options Flow</p>
        <p className="mt-3 text-lg font-semibold text-gray-900">{flowCount}</p>
        <div className="mt-1 flex justify-center gap-2 text-xs">
          <span className="text-bullish">{bullishFlow} Bull</span>
          <span className="text-gray-300">|</span>
          <span className="text-bearish">{bearishFlow} Bear</span>
        </div>
      </div>
      <div className="rounded-lg border border-gray-100 bg-gray-50/50 p-4 text-center">
        <p className="text-xs text-gray-500">Dark Pool Volume</p>
        <p className="mt-3 text-lg font-semibold text-gray-900">
          {dpVolume != null ? formatCompact(dpVolume) : "—"}
        </p>
        {dpNet != null && (
          <p className={`mt-1 text-xs font-medium ${dpNet > 0 ? "text-bullish" : dpNet < 0 ? "text-bearish" : "text-gray-500"}`}>
            Net: {dpNet > 0 ? "+" : ""}{formatCompact(dpNet)}
          </p>
        )}
      </div>
      <div className="rounded-lg border border-gray-100 bg-gray-50/50 p-4 text-center">
        <p className="text-xs text-gray-500">Data Status</p>
        <p className="mt-3 text-lg font-semibold text-gray-900">
          {basicData?.stale ? "⚠ Stale" : "✓ Live"}
        </p>
        {basicData?.data_as_of && (
          <p className="mt-1 text-xs text-gray-400">as of {basicData.data_as_of}</p>
        )}
      </div>
    </div>
  );
}

function OptionsFlowTable({ trades }: { trades: OptionsFlowTrade[] }) {
  const [filter, setFilter] = useState<FlowFilter>("all");

  const filtered = trades.filter((t) => {
    if (filter === "all") return true;
    const type = t.type?.toLowerCase() ?? "";
    if (filter === "calls") return type.includes("call");
    return type.includes("put");
  });

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <h3 className="text-sm font-semibold text-gray-700">Options Flow</h3>
        <div className="flex gap-1">
          {(["all", "calls", "puts"] as const).map((f) => (
            <button
              key={f}
              type="button"
              onClick={() => setFilter(f)}
              className={`rounded-lg px-3 py-1 text-xs font-medium capitalize ${
                filter === f
                  ? "bg-primary-600 text-white"
                  : "bg-gray-100 text-gray-600 hover:bg-gray-200"
              }`}
            >
              {f}
            </button>
          ))}
        </div>
      </div>
      {filtered.length === 0 ? (
        <p className="py-8 text-center text-sm text-gray-400">No options flow data</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="border-b border-gray-100 text-xs text-gray-500">
                <th className="pb-2 font-medium">Type</th>
                <th className="pb-2 font-medium">Strike</th>
                <th className="pb-2 font-medium">Expiry</th>
                <th className="pb-2 font-medium text-right">Premium</th>
                <th className="pb-2 font-medium text-right">Qty</th>
                <th className="pb-2 font-medium">Sentiment</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {filtered.map((t, i) => {
                const premium = t.premium ?? 0;
                const isLarge = premium >= 1_000_000;
                return (
                  <tr key={i} className={isLarge ? "bg-yellow-50/50" : ""}>
                    <td className="py-2 font-medium text-gray-900">{t.type ?? "—"}</td>
                    <td className="py-2 text-gray-700">{t.strike != null ? `$${t.strike}` : "—"}</td>
                    <td className="py-2 text-gray-700">{t.expiry ?? "—"}</td>
                    <td className={`py-2 text-right font-medium ${isLarge ? "text-yellow-700" : "text-gray-900"}`}>
                      {formatCurrency(t.premium)}
                      {isLarge && <span className="ml-1 text-xs">🔥</span>}
                    </td>
                    <td className="py-2 text-right text-gray-700">
                      {t.quantity != null ? t.quantity.toLocaleString() : "—"}
                    </td>
                    <td className="py-2"><SentimentBadge sentiment={t.sentiment} /></td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function DarkPoolSection({ darkPool }: { darkPool: InstitutionalData["dark_pool"] | null }) {
  if (!darkPool) {
    return (
      <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h3 className="mb-4 text-sm font-semibold text-gray-700">Dark Pool Activity</h3>
        <p className="py-4 text-center text-sm text-gray-400">No dark pool data available</p>
      </div>
    );
  }

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <h3 className="mb-4 text-sm font-semibold text-gray-700">Dark Pool Activity</h3>
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
        <div>
          <p className="text-xs text-gray-500">Volume</p>
          <p className="mt-1 text-lg font-semibold text-gray-900">
            {darkPool.volume != null ? formatCompact(darkPool.volume) : "—"}
          </p>
        </div>
        <div>
          <p className="text-xs text-gray-500">Net Buy/Sell</p>
          <p className={`mt-1 text-lg font-semibold ${
            (darkPool.net_buy_sell ?? 0) > 0 ? "text-bullish" :
            (darkPool.net_buy_sell ?? 0) < 0 ? "text-bearish" : "text-gray-900"
          }`}>
            {darkPool.net_buy_sell != null
              ? `${darkPool.net_buy_sell > 0 ? "+" : ""}${formatCompact(darkPool.net_buy_sell)}`
              : "—"}
          </p>
        </div>
        <div>
          <p className="text-xs text-gray-500">Block Trades</p>
          <p className="mt-1 text-lg font-semibold text-gray-900">
            {darkPool.block_trades?.length ?? 0}
          </p>
        </div>
      </div>
    </div>
  );
}

function CongressionalSection({ trades }: { trades: CongressionalTrade[] | null }) {
  if (!trades || trades.length === 0) {
    return (
      <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h3 className="mb-4 text-sm font-semibold text-gray-700">Congressional Trading</h3>
        <p className="py-4 text-center text-sm text-gray-400">No congressional trades found</p>
      </div>
    );
  }

  const buys = trades.filter((t) => t.transaction_type?.toLowerCase().includes("purchase")).length;
  const sells = trades.length - buys;

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div className="mb-4 flex items-center justify-between">
        <h3 className="text-sm font-semibold text-gray-700">Congressional Trading</h3>
        <div className="flex gap-3 text-xs">
          <span className="text-bullish">{buys} Buy</span>
          <span className="text-bearish">{sells} Sell</span>
        </div>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-gray-100 text-xs text-gray-500">
              <th className="pb-2 font-medium">Representative</th>
              <th className="pb-2 font-medium">Party</th>
              <th className="pb-2 font-medium">Type</th>
              <th className="pb-2 font-medium">Amount</th>
              <th className="pb-2 font-medium">Date</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {trades.slice(0, 10).map((t, i) => (
              <tr key={i}>
                <td className="py-2 font-medium text-gray-900">{t.representative ?? "—"}</td>
                <td className="py-2">
                  <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                    t.party === "Democrat" ? "bg-blue-50 text-blue-700" :
                    t.party === "Republican" ? "bg-red-50 text-red-700" :
                    "bg-gray-100 text-gray-600"
                  }`}>
                    {t.party ?? "—"}
                  </span>
                </td>
                <td className="py-2">
                  <SentimentBadge sentiment={t.transaction_type} />
                </td>
                <td className="py-2 text-gray-700">{t.amount ?? "—"}</td>
                <td className="py-2 text-gray-500">{formatDate(t.date)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="mt-4 text-xs text-gray-400">
        Data sourced from STOCK Act filings. Congressional trading data is reported with a delay and may not reflect current positions.
      </p>
    </div>
  );
}

function InsiderSection({ trades }: { trades: InsiderTrade[] | null }) {
  if (!trades || trades.length === 0) {
    return (
      <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h3 className="mb-4 text-sm font-semibold text-gray-700">Insider Transactions</h3>
        <p className="py-4 text-center text-sm text-gray-400">No insider trades found</p>
      </div>
    );
  }

  const buys = trades.filter((t) =>
    t.transaction_type?.toLowerCase().includes("buy") ||
    t.transaction_type?.toLowerCase().includes("purchase"),
  ).length;
  const sells = trades.length - buys;

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div className="mb-4 flex items-center justify-between">
        <h3 className="text-sm font-semibold text-gray-700">Insider Transactions</h3>
        <div className="flex gap-3 text-xs">
          <span className="text-bullish">{buys} Buy</span>
          <span className="text-bearish">{sells} Sell</span>
        </div>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-gray-100 text-xs text-gray-500">
              <th className="pb-2 font-medium">Name</th>
              <th className="pb-2 font-medium">Title</th>
              <th className="pb-2 font-medium">Type</th>
              <th className="pb-2 font-medium text-right">Shares</th>
              <th className="pb-2 font-medium text-right">Value</th>
              <th className="pb-2 font-medium">Date</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {trades.slice(0, 10).map((t, i) => (
              <tr key={i}>
                <td className="py-2 font-medium text-gray-900">{t.insider_name ?? "—"}</td>
                <td className="py-2 text-xs text-gray-500">{t.title ?? "—"}</td>
                <td className="py-2"><SentimentBadge sentiment={t.transaction_type} /></td>
                <td className="py-2 text-right text-gray-700">
                  {t.shares != null ? t.shares.toLocaleString() : "—"}
                </td>
                <td className="py-2 text-right text-gray-700">{formatCurrency(t.value)}</td>
                <td className="py-2 text-gray-500">{formatDate(t.date)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function HoldingsSection({ holdings }: { holdings: InstitutionalHolding[] | null }) {
  if (!holdings || holdings.length === 0) {
    return (
      <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h3 className="mb-4 text-sm font-semibold text-gray-700">Institutional Holdings (13F)</h3>
        <p className="py-4 text-center text-sm text-gray-400">No holdings data available</p>
      </div>
    );
  }

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <h3 className="mb-4 text-sm font-semibold text-gray-700">Top Institutional Holders (13F)</h3>
      <div className="overflow-x-auto">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-gray-100 text-xs text-gray-500">
              <th className="pb-2 font-medium">Holder</th>
              <th className="pb-2 font-medium text-right">Shares</th>
              <th className="pb-2 font-medium text-right">Value</th>
              <th className="pb-2 font-medium text-right">Change %</th>
              <th className="pb-2 font-medium">Report Date</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {holdings.slice(0, 15).map((h, i) => (
              <tr key={i}>
                <td className="py-2 font-medium text-gray-900">{h.holder ?? "—"}</td>
                <td className="py-2 text-right text-gray-700">
                  {h.shares != null ? h.shares.toLocaleString() : "—"}
                </td>
                <td className="py-2 text-right text-gray-700">{formatCurrency(h.value)}</td>
                <td className={`py-2 text-right font-medium ${
                  (h.change_percent ?? 0) > 0 ? "text-bullish" :
                  (h.change_percent ?? 0) < 0 ? "text-bearish" : "text-gray-500"
                }`}>
                  {h.change_percent != null
                    ? `${h.change_percent > 0 ? "+" : ""}${h.change_percent.toFixed(1)}%`
                    : "—"}
                </td>
                <td className="py-2 text-gray-500">{formatDate(h.date)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
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
      stocksApi.getCongressional(ticker).then((res) => setCongressional(res.trades)),
      stocksApi.getInsiderTrades(ticker).then((res) => setInsider(res.trades)),
      stocksApi.getHoldings(ticker).then((res) => setHoldings(res.holdings)),
      stocksApi.getSmartMoneyScore(ticker).then(setSmartMoney),
    ])
      .then((results) => {
        const allFailed = results.every((r) => r.status === "rejected");
        if (allFailed) setError(true);
      })
      .finally(() => setLoading(false));
  }, [ticker]);

  if (loading) {
    return (
      <section className="mt-6 space-y-4">
        <div className="h-32 animate-pulse rounded-xl bg-gray-100" />
        <div className="h-48 animate-pulse rounded-xl bg-gray-100" />
        <div className="h-40 animate-pulse rounded-xl bg-gray-100" />
        <div className="h-40 animate-pulse rounded-xl bg-gray-100" />
      </section>
    );
  }

  if (error) {
    return (
      <section className="mt-6 rounded-xl border border-gray-200 bg-white p-12 text-center shadow-sm">
        <p className="text-gray-500">Institutional data unavailable</p>
      </section>
    );
  }

  return (
    <section className="mt-6 space-y-6">
      <QuickStatsCards smartMoney={smartMoney} basicData={basicData} />

      <OptionsFlowTable trades={basicData?.options_flow ?? []} />

      <DarkPoolSection darkPool={basicData?.dark_pool ?? null} />

      <CongressionalSection trades={congressional} />

      <InsiderSection trades={insider} />

      <HoldingsSection holdings={holdings} />

      <p className="text-center text-xs text-gray-400">
        Institutional data is for informational purposes only and does not constitute investment advice.
        Congressional trading data is sourced from public STOCK Act filings.
      </p>
    </section>
  );
}

"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import {
  Area,
  AreaChart,
  Legend,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import type {
  PaperPortfolio,
  EnrichedHolding,
  PortfolioPerformance,
  TradeMetric,
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

function colorClass(value: string | null | undefined): string {
  if (value == null) return "text-zinc-500";
  const n = parseFloat(value);
  if (Number.isNaN(n)) return "text-zinc-500";
  return n > 0 ? "text-bullish" : n < 0 ? "text-bearish" : "text-zinc-500";
}

function StatCard({
  label,
  value,
  subValue,
  colorize,
}: {
  label: string;
  value: string;
  subValue?: string;
  colorize?: boolean;
}) {
  return (
    <div className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
      <p className="text-xs font-medium tracking-wide text-zinc-500 uppercase dark:text-zinc-400">{label}</p>
      <p className={`mt-1 text-xl font-bold ${colorize ? colorClass(value) : "text-zinc-900 dark:text-zinc-100"}`}>
        {colorize ? fmtDollar(value) : value}
      </p>
      {subValue && (
        <p className={`mt-0.5 text-sm ${colorize ? colorClass(subValue) : "text-zinc-500 dark:text-zinc-400"}`}>
          {colorize ? fmtPct(subValue) : subValue}
        </p>
      )}
    </div>
  );
}

function TradeMetricCard({ label, trade }: { label: string; trade: TradeMetric | null }) {
  if (!trade) {
    return (
      <div className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
        <p className="text-xs font-medium tracking-wide text-zinc-500 uppercase dark:text-zinc-400">{label}</p>
        <p className="mt-1 text-xl font-bold text-zinc-400 dark:text-zinc-500">—</p>
      </div>
    );
  }
  return (
    <div className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
      <p className="text-xs font-medium tracking-wide text-zinc-500 uppercase dark:text-zinc-400">{label}</p>
      <p className="mt-1 text-lg font-bold text-zinc-900 dark:text-zinc-100">{trade.ticker}</p>
      <p className={`text-sm font-medium ${colorClass(trade.gain_percent)}`}>
        {fmtDollar(trade.gain)} ({fmtPct(trade.gain_percent)})
      </p>
    </div>
  );
}

export default function PortfolioDetailPage() {
  const params = useParams();
  const portfolioId = typeof params.portfolioId === "string" ? params.portfolioId : "";

  const [portfolio, setPortfolio] = useState<PaperPortfolio | null>(null);
  const [portfolioNotFound, setPortfolioNotFound] = useState(false);
  const [holdings, setHoldings] = useState<EnrichedHolding[]>([]);
  const [performance, setPerformance] = useState<PortfolioPerformance | null>(null);
  const [transactions, setTransactions] = useState<TransactionDetail[]>([]);
  const [metaLoading, setMetaLoading] = useState(true);
  const [holdingsLoading, setHoldingsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!portfolioId) return;
    setMetaLoading(true);
    setPortfolioNotFound(false);
    setPortfolio(null);
    setError(null);
    paperTradingApi
      .getPortfolio(portfolioId)
      .then((r) => setPortfolio(r.data))
      .catch(() => setPortfolioNotFound(true))
      .finally(() => setMetaLoading(false));
  }, [portfolioId]);

  const loadDetails = useCallback((id: string) => {
    setHoldingsLoading(true);
    Promise.all([
      paperTradingApi.listHoldings(id),
      paperTradingApi.getPerformance(id),
      paperTradingApi.listTransactions(id, { per_page: 500 }).catch(() => ({
        data: [] as TransactionDetail[],
        meta: { page: 1, per_page: 500, total_pages: 0, total_count: 0 },
      })),
    ])
      .then(([h, p, txRes]) => {
        setHoldings(h.data);
        setPerformance(p.data);
        setTransactions(txRes.data ?? []);
      })
      .catch(() => setError("Failed to load portfolio details"))
      .finally(() => setHoldingsLoading(false));
  }, []);

  useEffect(() => {
    if (portfolioId && portfolio && !portfolioNotFound) loadDetails(portfolioId);
  }, [portfolioId, portfolio, portfolioNotFound, loadDetails]);

  const performanceChartData = useMemo(() => {
    if (!portfolio || !performance) return [];
    const start = parseFloat(portfolio.starting_balance);
    const endValue = parseFloat(performance.total_value);
    const sorted = [...transactions].sort(
      (a, b) => new Date(a.executed_at).getTime() - new Date(b.executed_at).getTime(),
    );

    const points: { date: string; value: number; display: string }[] = [];
    const startDate = portfolio.inserted_at ?? new Date().toISOString();
    points.push({
      date: startDate,
      value: start,
      display: new Date(startDate).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "2-digit" }),
    });

    let cash = start;
    const holdingsState: Record<string, { qty: number; totalCost: number }> = {};

    for (const tx of sorted) {
      const amount = parseFloat(tx.total_amount);
      const qty = parseFloat(tx.quantity);
      const isBuy = tx.transaction_type?.toLowerCase() === "buy";

      if (isBuy) {
        cash -= amount;
        const cur = holdingsState[tx.ticker] ?? { qty: 0, totalCost: 0 };
        holdingsState[tx.ticker] = { qty: cur.qty + qty, totalCost: cur.totalCost + amount };
      } else {
        cash += amount;
        const cur = holdingsState[tx.ticker];
        if (cur) {
          const costPerShare = cur.totalCost / cur.qty;
          cur.qty -= qty;
          cur.totalCost = cur.qty * costPerShare;
          if (cur.qty <= 0) delete holdingsState[tx.ticker];
        }
      }

      const value = cash + Object.values(holdingsState).reduce((s, h) => s + h.totalCost, 0);
      points.push({
        date: tx.executed_at,
        value: Math.round(value * 100) / 100,
        display: new Date(tx.executed_at).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "2-digit" }),
      });
    }

    const today = new Date().toISOString();
    points.push({
      date: today,
      value: endValue,
      display: new Date().toLocaleDateString("en-US", { month: "short", day: "numeric", year: "2-digit" }),
    });

    return points.sort((a, b) => a.date.localeCompare(b.date));
  }, [portfolio, performance, transactions]);

  const chartFillId = `portfolioFill-${portfolioId.replace(/[^a-zA-Z0-9]/g, "") || "default"}`;

  if (metaLoading) {
    return (
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
        <div className="h-8 w-48 animate-pulse rounded bg-zinc-100 dark:bg-zinc-700" />
        <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="h-24 animate-pulse rounded-xl bg-zinc-100 dark:bg-zinc-700" />
          ))}
        </div>
        <div className="mt-6 h-64 animate-pulse rounded-xl bg-zinc-100 dark:bg-zinc-700" />
      </div>
    );
  }

  if (portfolioNotFound || !portfolio) {
    return (
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
        <p className="text-bearish">Portfolio not found.</p>
        <Link href="/portfolio" className="mt-4 inline-block text-primary-600 hover:underline dark:text-primary-400">
          Back to portfolios
        </Link>
      </div>
    );
  }

  if (error && !performance) {
    return (
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
        <p className="text-bearish">{error}</p>
        <Link href="/dashboard" className="mt-4 inline-block text-primary-600 hover:underline dark:text-primary-400">
          Back to dashboard
        </Link>
      </div>
    );
  }

  const totalValue = performance ? parseFloat(performance.total_value) : 0;
  const startingBalance = parseFloat(portfolio.starting_balance);
  const totalReturnPct = performance?.total_return ?? "0";
  const totalReturnDollar = performance ? (totalValue - startingBalance).toFixed(2) : "0";

  const holdingsValue = performance ? parseFloat(performance.holdings_value) : 0;
  const cashBalance = performance ? parseFloat(performance.cash_balance) : 0;

  const allocationData = holdings.map((h) => ({
    ticker: h.ticker,
    value: parseFloat(h.current_value),
  }));
  if (cashBalance > 0) {
    allocationData.push({ ticker: "Cash", value: cashBalance });
  }

  return (
    <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
      <Link
        href="/dashboard"
        className="mb-4 inline-block text-sm text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-100"
      >
        ← Dashboard
      </Link>

      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-zinc-900 dark:text-zinc-100">{portfolio.name}</h1>
          {portfolio.description && (
            <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">{portfolio.description}</p>
          )}
        </div>
      </div>

      <section className="mt-6 rounded-xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
        <p className="text-sm font-medium text-zinc-500 dark:text-zinc-400">Total Portfolio Value</p>
        <div className="mt-1 flex flex-wrap items-baseline gap-4">
          <span className="text-3xl font-bold text-zinc-900 dark:text-zinc-100">${fmt(performance?.total_value)}</span>
          <span className={`text-lg font-semibold ${colorClass(totalReturnDollar)}`}>{fmtDollar(totalReturnDollar)}</span>
          <span className={`text-sm ${colorClass(totalReturnPct)}`}>({fmtPct(totalReturnPct)})</span>
        </div>
        <div className="mt-4 flex flex-wrap gap-6 text-sm">
          <div>
            <span className="text-zinc-500 dark:text-zinc-400">Cash Available</span>
            <span className="ml-2 font-semibold text-zinc-900 dark:text-zinc-100">${fmt(performance?.cash_balance)}</span>
          </div>
          <div>
            <span className="text-zinc-500 dark:text-zinc-400">Holdings Value</span>
            <span className="ml-2 font-semibold text-zinc-900 dark:text-zinc-100">${fmt(performance?.holdings_value)}</span>
          </div>
          <div>
            <span className="text-zinc-500 dark:text-zinc-400">Starting Balance</span>
            <span className="ml-2 font-medium text-zinc-600 dark:text-zinc-400">${fmt(portfolio.starting_balance)}</span>
          </div>
        </div>
      </section>

      {holdingsLoading ? (
        <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
          {[1, 2, 3, 4, 5].map((i) => (
            <div key={i} className="h-24 animate-pulse rounded-xl bg-zinc-100 dark:bg-zinc-700" />
          ))}
        </div>
      ) : performance ? (
        <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
          <StatCard label="Realized Gains" value={performance.realized_gains} colorize />
          <StatCard label="Unrealized Gains" value={performance.unrealized_gains} colorize />
          <StatCard
            label="Win Rate"
            value={`${fmtPct(performance.win_rate).replace("+", "")}`}
            subValue={`${performance.profitable_sells}/${performance.total_sells} sells`}
          />
          <TradeMetricCard label="Best Trade" trade={performance.best_trade} />
          <TradeMetricCard label="Worst Trade" trade={performance.worst_trade} />
        </div>
      ) : null}

      <section className="mt-6 rounded-xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
        <h2 className="text-sm font-semibold text-zinc-700 dark:text-zinc-300">Performance Over Time</h2>
        {performanceChartData.length >= 2 ? (
          <div className="mt-4 h-64">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={performanceChartData} margin={{ top: 8, right: 8, left: 8, bottom: 8 }}>
                <defs>
                  <linearGradient id={chartFillId} x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="var(--color-primary-500)" stopOpacity={0.3} />
                    <stop offset="100%" stopColor="var(--color-primary-500)" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis
                  dataKey="display"
                  tick={{ fontSize: 11 }}
                  tickLine={false}
                  axisLine={false}
                  interval="preserveStartEnd"
                />
                <YAxis
                  tickFormatter={(v) => `$${(v / 1000).toFixed(0)}k`}
                  tick={{ fontSize: 11 }}
                  tickLine={false}
                  axisLine={false}
                  width={40}
                />
                <Legend align="left" />
                <Tooltip
                  formatter={(value: number) => [
                    `$${value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`,
                    "Value",
                  ]}
                  labelFormatter={(_, payload) => payload?.[0]?.payload?.display ?? ""}
                  contentStyle={{ borderRadius: "8px", border: "1px solid #e5e7eb" }}
                />
                <Area
                  type="monotone"
                  dataKey="value"
                  name="Value"
                  stroke="var(--color-primary-600)"
                  strokeWidth={2}
                  fill={`url(#${chartFillId})`}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        ) : (
          <div className="mt-4 flex h-48 items-center justify-center rounded-lg bg-zinc-50 text-sm text-zinc-400 dark:bg-zinc-700/50 dark:text-zinc-500">
            Execute trades to see portfolio value over time.
          </div>
        )}
      </section>

      <section className="mt-6">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-zinc-900 dark:text-zinc-100">Holdings</h2>
          <span className="text-sm text-zinc-500 dark:text-zinc-400">
            {holdings.length} position{holdings.length !== 1 ? "s" : ""}
          </span>
        </div>
        {holdingsLoading ? (
          <div className="mt-4 h-48 animate-pulse rounded-xl bg-zinc-100 dark:bg-zinc-700" />
        ) : holdings.length > 0 ? (
          <div className="mt-4 overflow-x-auto rounded-xl border border-zinc-200 bg-white shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-zinc-100 bg-zinc-50 text-left text-xs font-medium tracking-wide text-zinc-500 uppercase dark:border-zinc-700 dark:bg-zinc-700/50 dark:text-zinc-400">
                  <th className="px-4 py-3">Ticker</th>
                  <th className="px-4 py-3 text-right">Qty</th>
                  <th className="px-4 py-3 text-right">Avg Cost</th>
                  <th className="px-4 py-3 text-right">Price</th>
                  <th className="px-4 py-3 text-right">Value</th>
                  <th className="px-4 py-3 text-right">Gain/Loss</th>
                  <th className="px-4 py-3 text-right">%</th>
                  <th className="px-4 py-3 text-right">% of Portfolio</th>
                </tr>
              </thead>
              <tbody>
                {holdings.map((h) => {
                  const value = parseFloat(h.current_value);
                  const portfolioPct = totalValue > 0 ? ((value / totalValue) * 100).toFixed(1) : "0.0";
                  return (
                    <tr
                      key={h.id}
                      className="border-b border-zinc-50 transition-colors hover:bg-zinc-50 dark:border-zinc-700 dark:hover:bg-zinc-700/50"
                    >
                      <td className="px-4 py-3">
                        <Link
                          href={`/stocks/${encodeURIComponent(h.ticker)}`}
                          className="font-semibold text-primary-600 hover:underline"
                        >
                          {h.ticker}
                        </Link>
                      </td>
                      <td className="px-4 py-3 text-right font-medium text-zinc-900 dark:text-zinc-100">{fmt(h.quantity)}</td>
                      <td className="px-4 py-3 text-right text-zinc-600 dark:text-zinc-400">${fmt(h.average_cost)}</td>
                      <td className="px-4 py-3 text-right font-medium text-zinc-900 dark:text-zinc-100">${fmt(h.current_price)}</td>
                      <td className="px-4 py-3 text-right font-medium text-zinc-900 dark:text-zinc-100">${fmt(h.current_value)}</td>
                      <td className={`px-4 py-3 text-right font-medium ${colorClass(h.gain_loss)}`}>{fmtDollar(h.gain_loss)}</td>
                      <td className={`px-4 py-3 text-right font-medium ${colorClass(h.gain_loss_percent)}`}>
                        {fmtPct(h.gain_loss_percent)}
                      </td>
                      <td className="px-4 py-3 text-right text-zinc-600 dark:text-zinc-400">{portfolioPct}%</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="mt-4 flex flex-col items-center rounded-xl border border-zinc-200 bg-white py-12 text-center shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
            <p className="text-zinc-500 dark:text-zinc-400">No holdings yet</p>
            <p className="mt-1 text-sm text-zinc-400 dark:text-zinc-500">
              Start by analyzing a stock and placing a paper trade.
            </p>
            <Link
              href="/dashboard"
              className="mt-4 rounded-lg bg-primary-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-primary-700"
            >
              Find a stock
            </Link>
          </div>
        )}
      </section>

      {performance && (
        <section className="mt-6 rounded-xl border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-semibold text-zinc-700 dark:text-zinc-300">Trading Summary</h2>
            <Link
              href={`/portfolio/${portfolioId}/transactions`}
              className="text-sm font-medium text-primary-600 hover:underline dark:text-primary-400"
            >
              View all transactions →
            </Link>
          </div>
          <dl className="mt-4 grid grid-cols-2 gap-4 text-sm sm:grid-cols-4">
            <div>
              <dt className="text-zinc-500 dark:text-zinc-400">Total Trades</dt>
              <dd className="mt-1 text-lg font-bold text-zinc-900 dark:text-zinc-100">{performance.total_trades}</dd>
            </div>
            <div>
              <dt className="text-zinc-500 dark:text-zinc-400">Total Sells</dt>
              <dd className="mt-1 text-lg font-bold text-zinc-900 dark:text-zinc-100">{performance.total_sells}</dd>
            </div>
            <div>
              <dt className="text-zinc-500 dark:text-zinc-400">Profitable Sells</dt>
              <dd className="mt-1 text-lg font-bold text-bullish">{performance.profitable_sells}</dd>
            </div>
            <div>
              <dt className="text-zinc-500 dark:text-zinc-400">Most Traded</dt>
              <dd className="mt-1 text-lg font-bold text-zinc-900 dark:text-zinc-100">{performance.most_traded_ticker ?? "—"}</dd>
            </div>
          </dl>
        </section>
      )}
    </div>
  );
}

"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import type {
  PaperPortfolio,
  EnrichedHolding,
  PortfolioPerformance,
  TradeMetric,
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
  if (value == null) return "text-gray-500";
  const n = parseFloat(value);
  if (Number.isNaN(n)) return "text-gray-500";
  return n > 0 ? "text-bullish" : n < 0 ? "text-bearish" : "text-gray-500";
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
    <div className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
      <p className="text-xs font-medium tracking-wide text-gray-500 uppercase">{label}</p>
      <p className={`mt-1 text-xl font-bold ${colorize ? colorClass(value) : "text-gray-900"}`}>
        {colorize ? fmtDollar(value) : value}
      </p>
      {subValue && (
        <p className={`mt-0.5 text-sm ${colorize ? colorClass(subValue) : "text-gray-500"}`}>
          {colorize ? fmtPct(subValue) : subValue}
        </p>
      )}
    </div>
  );
}

function TradeMetricCard({ label, trade }: { label: string; trade: TradeMetric | null }) {
  if (!trade) {
    return (
      <div className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
        <p className="text-xs font-medium tracking-wide text-gray-500 uppercase">{label}</p>
        <p className="mt-1 text-xl font-bold text-gray-400">—</p>
      </div>
    );
  }
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
      <p className="text-xs font-medium tracking-wide text-gray-500 uppercase">{label}</p>
      <p className="mt-1 text-lg font-bold text-gray-900">{trade.ticker}</p>
      <p className={`text-sm font-medium ${colorClass(trade.gain_percent)}`}>
        {fmtDollar(trade.gain)} ({fmtPct(trade.gain_percent)})
      </p>
    </div>
  );
}

export default function PortfolioPage() {
  const [portfolios, setPortfolios] = useState<PaperPortfolio[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [holdings, setHoldings] = useState<EnrichedHolding[]>([]);
  const [performance, setPerformance] = useState<PortfolioPerformance | null>(null);
  const [loading, setLoading] = useState(true);
  const [holdingsLoading, setHoldingsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [creatingPortfolio, setCreatingPortfolio] = useState(false);

  useEffect(() => {
    setLoading(true);
    paperTradingApi
      .listPortfolios()
      .then((res) => {
        const list = res.data;
        setPortfolios(list);
        if (list.length > 0 && !selectedId) {
          setSelectedId(list[0]!.id);
        }
      })
      .catch(() => setError("Failed to load portfolios"))
      .finally(() => setLoading(false));
  }, []);

  const loadDetails = useCallback((id: string) => {
    setHoldingsLoading(true);
    Promise.all([
      paperTradingApi.listHoldings(id),
      paperTradingApi.getPerformance(id),
    ])
      .then(([h, p]) => {
        setHoldings(h.data);
        setPerformance(p.data);
      })
      .catch(() => setError("Failed to load portfolio details"))
      .finally(() => setHoldingsLoading(false));
  }, []);

  useEffect(() => {
    if (selectedId) loadDetails(selectedId);
  }, [selectedId, loadDetails]);

  const selectedPortfolio = portfolios.find((p) => p.id === selectedId);

  const handleCreatePortfolio = async () => {
    setCreatingPortfolio(true);
    try {
      const res = await paperTradingApi.createPortfolio({ name: "My Portfolio" });
      setPortfolios((prev) => [...prev, res.data]);
      setSelectedId(res.data.id);
    } catch {
      setError("Failed to create portfolio");
    } finally {
      setCreatingPortfolio(false);
    }
  };

  if (loading) {
    return (
      <div className="mx-auto max-w-5xl px-4 py-8 sm:px-6">
        <div className="h-8 w-48 animate-pulse rounded bg-gray-100" />
        <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="h-24 animate-pulse rounded-xl bg-gray-100" />
          ))}
        </div>
        <div className="mt-6 h-64 animate-pulse rounded-xl bg-gray-100" />
      </div>
    );
  }

  if (error && !selectedPortfolio) {
    return (
      <div className="mx-auto max-w-5xl px-4 py-8 sm:px-6">
        <p className="text-bearish">{error}</p>
        <Link href="/dashboard" className="mt-4 inline-block text-primary-600 hover:underline">
          Back to dashboard
        </Link>
      </div>
    );
  }

  if (portfolios.length === 0) {
    return (
      <div className="mx-auto max-w-5xl px-4 py-8 sm:px-6">
        <h1 className="text-2xl font-bold text-gray-900">Paper Trading Portfolio</h1>
        <div className="mt-12 flex flex-col items-center text-center">
          <div className="rounded-full bg-primary-50 p-6">
            <svg className="h-12 w-12 text-primary-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 6v12m6-6H6" />
            </svg>
          </div>
          <h2 className="mt-4 text-lg font-semibold text-gray-900">No portfolio yet</h2>
          <p className="mt-2 max-w-sm text-sm text-gray-500">
            Create your first paper trading portfolio to start practicing trades with $100,000 in virtual cash.
          </p>
          <button
            type="button"
            onClick={handleCreatePortfolio}
            disabled={creatingPortfolio}
            className="mt-6 rounded-lg bg-primary-600 px-6 py-2.5 text-sm font-medium text-white transition-colors hover:bg-primary-700 disabled:opacity-50"
          >
            {creatingPortfolio ? "Creating..." : "Create Portfolio"}
          </button>
        </div>
      </div>
    );
  }

  const totalValue = performance ? parseFloat(performance.total_value) : 0;
  const startingBalance = selectedPortfolio ? parseFloat(selectedPortfolio.starting_balance) : 100000;
  const totalReturnPct = performance?.total_return ?? "0";
  const totalReturnDollar = performance
    ? (totalValue - startingBalance).toFixed(2)
    : "0";

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
    <div className="mx-auto max-w-5xl px-4 py-6 sm:px-6">
      <Link
        href="/dashboard"
        className="mb-4 inline-block text-sm text-gray-500 hover:text-gray-900"
      >
        ← Dashboard
      </Link>

      {/* Header */}
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">
            {selectedPortfolio?.name ?? "Portfolio"}
          </h1>
          {selectedPortfolio?.description && (
            <p className="mt-1 text-sm text-gray-500">{selectedPortfolio.description}</p>
          )}
        </div>
        {portfolios.length > 1 && (
          <select
            value={selectedId ?? ""}
            onChange={(e) => setSelectedId(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm text-gray-700"
          >
            {portfolios.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
        )}
      </div>

      {/* Portfolio Value */}
      <section className="mt-6 rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <p className="text-sm font-medium text-gray-500">Total Portfolio Value</p>
        <div className="mt-1 flex flex-wrap items-baseline gap-4">
          <span className="text-3xl font-bold text-gray-900">
            ${fmt(performance?.total_value)}
          </span>
          <span className={`text-lg font-semibold ${colorClass(totalReturnDollar)}`}>
            {fmtDollar(totalReturnDollar)}
          </span>
          <span className={`text-sm ${colorClass(totalReturnPct)}`}>
            ({fmtPct(totalReturnPct)})
          </span>
        </div>
        <div className="mt-4 flex flex-wrap gap-6 text-sm">
          <div>
            <span className="text-gray-500">Cash Available</span>
            <span className="ml-2 font-semibold text-gray-900">${fmt(performance?.cash_balance)}</span>
          </div>
          <div>
            <span className="text-gray-500">Holdings Value</span>
            <span className="ml-2 font-semibold text-gray-900">${fmt(performance?.holdings_value)}</span>
          </div>
          <div>
            <span className="text-gray-500">Starting Balance</span>
            <span className="ml-2 font-medium text-gray-600">${fmt(selectedPortfolio?.starting_balance)}</span>
          </div>
        </div>
      </section>

      {/* Quick Stats */}
      {holdingsLoading ? (
        <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
          {[1, 2, 3, 4, 5].map((i) => (
            <div key={i} className="h-24 animate-pulse rounded-xl bg-gray-100" />
          ))}
        </div>
      ) : performance ? (
        <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
          <StatCard
            label="Realized Gains"
            value={performance.realized_gains}
            colorize
          />
          <StatCard
            label="Unrealized Gains"
            value={performance.unrealized_gains}
            colorize
          />
          <StatCard
            label="Win Rate"
            value={`${fmtPct(performance.win_rate).replace("+", "")}`}
            subValue={`${performance.profitable_sells}/${performance.total_sells} sells`}
          />
          <TradeMetricCard label="Best Trade" trade={performance.best_trade} />
          <TradeMetricCard label="Worst Trade" trade={performance.worst_trade} />
        </div>
      ) : null}

      {/* Performance Chart Placeholder */}
      <section className="mt-6 rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h2 className="text-sm font-semibold text-gray-700">Performance Over Time</h2>
        <div className="mt-4 flex h-48 items-center justify-center rounded-lg bg-gray-50 text-sm text-gray-400">
          Historical portfolio value chart coming soon (requires Milestone 6 — historical data snapshots)
        </div>
      </section>

      {/* Holdings Table */}
      <section className="mt-6">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-gray-900">Holdings</h2>
          <span className="text-sm text-gray-500">{holdings.length} position{holdings.length !== 1 ? "s" : ""}</span>
        </div>
        {holdingsLoading ? (
          <div className="mt-4 h-48 animate-pulse rounded-xl bg-gray-100" />
        ) : holdings.length > 0 ? (
          <div className="mt-4 overflow-x-auto rounded-xl border border-gray-200 bg-white shadow-sm">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-100 bg-gray-50 text-left text-xs font-medium tracking-wide text-gray-500 uppercase">
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
                    <tr key={h.id} className="border-b border-gray-50 transition-colors hover:bg-gray-50">
                      <td className="px-4 py-3">
                        <Link
                          href={`/stocks/${encodeURIComponent(h.ticker)}`}
                          className="font-semibold text-primary-600 hover:underline"
                        >
                          {h.ticker}
                        </Link>
                      </td>
                      <td className="px-4 py-3 text-right font-medium text-gray-900">{fmt(h.quantity)}</td>
                      <td className="px-4 py-3 text-right text-gray-600">${fmt(h.average_cost)}</td>
                      <td className="px-4 py-3 text-right font-medium text-gray-900">${fmt(h.current_price)}</td>
                      <td className="px-4 py-3 text-right font-medium text-gray-900">${fmt(h.current_value)}</td>
                      <td className={`px-4 py-3 text-right font-medium ${colorClass(h.gain_loss)}`}>
                        {fmtDollar(h.gain_loss)}
                      </td>
                      <td className={`px-4 py-3 text-right font-medium ${colorClass(h.gain_loss_percent)}`}>
                        {fmtPct(h.gain_loss_percent)}
                      </td>
                      <td className="px-4 py-3 text-right text-gray-600">{portfolioPct}%</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="mt-4 flex flex-col items-center rounded-xl border border-gray-200 bg-white py-12 text-center shadow-sm">
            <p className="text-gray-500">No holdings yet</p>
            <p className="mt-1 text-sm text-gray-400">
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

      {/* Summary Stats */}
      {performance && (
        <section className="mt-6 rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
          <h2 className="text-sm font-semibold text-gray-700">Trading Summary</h2>
          <dl className="mt-4 grid grid-cols-2 gap-4 text-sm sm:grid-cols-4">
            <div>
              <dt className="text-gray-500">Total Trades</dt>
              <dd className="mt-1 text-lg font-bold text-gray-900">{performance.total_trades}</dd>
            </div>
            <div>
              <dt className="text-gray-500">Total Sells</dt>
              <dd className="mt-1 text-lg font-bold text-gray-900">{performance.total_sells}</dd>
            </div>
            <div>
              <dt className="text-gray-500">Profitable Sells</dt>
              <dd className="mt-1 text-lg font-bold text-bullish">{performance.profitable_sells}</dd>
            </div>
            <div>
              <dt className="text-gray-500">Most Traded</dt>
              <dd className="mt-1 text-lg font-bold text-gray-900">
                {performance.most_traded_ticker ?? "—"}
              </dd>
            </div>
          </dl>
        </section>
      )}
    </div>
  );
}

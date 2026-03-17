"use client";

import { Fragment, useCallback, useEffect, useState } from "react";
import Link from "next/link";
import type {
  PaperPortfolio,
  TransactionDetail,
  PaginationMeta,
} from "@repo/types";
import { paperTradingApi } from "@/lib/api";

function fmt(value: string | null | undefined): string {
  if (value == null) return "—";
  const n = parseFloat(value);
  if (Number.isNaN(n)) return "—";
  return n.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function fmtDate(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

function fmtTime(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
}

export default function TransactionsPage() {
  const [portfolios, setPortfolios] = useState<PaperPortfolio[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [transactions, setTransactions] = useState<TransactionDetail[]>([]);
  const [meta, setMeta] = useState<PaginationMeta | null>(null);
  const [loading, setLoading] = useState(true);
  const [txLoading, setTxLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [page, setPage] = useState(1);
  const [tickerFilter, setTickerFilter] = useState("");
  const [typeFilter, setTypeFilter] = useState<"" | "buy" | "sell">("");
  const [expandedId, setExpandedId] = useState<string | null>(null);

  const perPage = 20;

  useEffect(() => {
    paperTradingApi
      .listPortfolios()
      .then((res) => {
        const list = res.data;
        setPortfolios(list);
        if (list.length > 0) setSelectedId(list[0]!.id);
      })
      .catch(() => setError("Failed to load portfolios"))
      .finally(() => setLoading(false));
  }, []);

  const loadTransactions = useCallback(() => {
    if (!selectedId) return;
    setTxLoading(true);
    paperTradingApi
      .listTransactions(selectedId, {
        page,
        per_page: perPage,
        ticker: tickerFilter || undefined,
        type: typeFilter || undefined,
      })
      .then((res) => {
        setTransactions(res.data);
        setMeta(res.meta);
      })
      .catch(() => setError("Failed to load transactions"))
      .finally(() => setTxLoading(false));
  }, [selectedId, page, tickerFilter, typeFilter]);

  useEffect(() => {
    if (selectedId) loadTransactions();
  }, [selectedId, loadTransactions]);

  useEffect(() => {
    setPage(1);
  }, [tickerFilter, typeFilter, selectedId]);

  const totalPages = meta?.total_pages ?? 1;

  if (loading) {
    return (
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
        <div className="h-8 w-48 animate-pulse rounded bg-zinc-100 dark:bg-zinc-700" />
        <div className="mt-6 h-64 animate-pulse rounded-xl bg-zinc-100 dark:bg-zinc-700" />
      </div>
    );
  }

  if (error && !selectedId) {
    return (
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
        <p className="text-bearish">{error}</p>
        <Link href="/portfolio" className="mt-4 inline-block text-primary-600 hover:underline">
          Back to portfolio
        </Link>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
      <Link
        href="/portfolio"
        className="mb-4 inline-block text-sm text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-100"
      >
        ← Portfolio
      </Link>

      <div className="flex flex-wrap items-center justify-between gap-4">
        <h1 className="text-2xl font-bold text-zinc-900 dark:text-zinc-100">Transaction History</h1>
        {portfolios.length > 1 && (
          <select
            value={selectedId ?? ""}
            onChange={(e) => setSelectedId(e.target.value)}
            className="rounded-lg border border-zinc-300 px-3 py-1.5 text-sm text-zinc-700 dark:border-zinc-600 dark:bg-zinc-800 dark:text-zinc-200"
          >
            {portfolios.map((p) => (
              <option key={p.id} value={p.id}>{p.name}</option>
            ))}
          </select>
        )}
      </div>

      {/* Filters */}
      <div className="mt-6 flex flex-wrap gap-3">
        <input
          type="text"
          value={tickerFilter}
          onChange={(e) => setTickerFilter(e.target.value.toUpperCase())}
          placeholder="Filter by ticker..."
          className="rounded-lg border border-zinc-300 px-3 py-2 text-sm placeholder:text-zinc-400 focus:border-primary-500 focus:outline-none focus:ring-2 focus:ring-primary-500/20 dark:border-zinc-600 dark:bg-zinc-800 dark:text-zinc-100 dark:placeholder:text-zinc-500"
        />
        <select
          value={typeFilter}
          onChange={(e) => setTypeFilter(e.target.value as "" | "buy" | "sell")}
          className="rounded-lg border border-zinc-300 px-3 py-2 text-sm text-zinc-700 dark:border-zinc-600 dark:bg-zinc-800 dark:text-zinc-200"
        >
          <option value="">All types</option>
          <option value="buy">Buy only</option>
          <option value="sell">Sell only</option>
        </select>
        {(tickerFilter || typeFilter) && (
          <button
            type="button"
            onClick={() => { setTickerFilter(""); setTypeFilter(""); }}
            className="rounded-lg px-3 py-2 text-sm text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-100"
          >
            Clear filters
          </button>
        )}
      </div>

      {/* Transactions Table */}
      {txLoading ? (
        <div className="mt-6 h-64 animate-pulse rounded-xl bg-zinc-100 dark:bg-zinc-700" />
      ) : transactions.length > 0 ? (
        <>
          <div className="mt-6 overflow-x-auto rounded-xl border border-zinc-200 bg-white shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-zinc-100 bg-zinc-50 text-left text-xs font-medium tracking-wide text-zinc-500 uppercase dark:border-zinc-700 dark:bg-zinc-700/50 dark:text-zinc-400">
                  <th className="px-4 py-3">Date</th>
                  <th className="px-4 py-3">Ticker</th>
                  <th className="px-4 py-3">Type</th>
                  <th className="px-4 py-3 text-right">Qty</th>
                  <th className="px-4 py-3 text-right">Price</th>
                  <th className="px-4 py-3 text-right">Total</th>
                </tr>
              </thead>
              <tbody>
                {transactions.map((tx) => (
                  <Fragment key={tx.id}>
                    <tr
                      onClick={() => setExpandedId(expandedId === tx.id ? null : tx.id)}
                      className="cursor-pointer border-b border-zinc-50 transition-colors hover:bg-zinc-50 dark:border-zinc-700 dark:hover:bg-zinc-700/50"
                    >
                      <td className="px-4 py-3">
                        <span className="text-zinc-900 dark:text-zinc-100">{fmtDate(tx.executed_at)}</span>
                        <span className="ml-2 text-xs text-zinc-400 dark:text-zinc-500">{fmtTime(tx.executed_at)}</span>
                      </td>
                      <td className="px-4 py-3 font-semibold text-zinc-900 dark:text-zinc-100">{tx.ticker}</td>
                      <td className="px-4 py-3">
                        <span
                          className={`rounded-full px-2 py-0.5 text-xs font-semibold uppercase ${
                            tx.transaction_type === "buy"
                              ? "bg-bullish-light text-bullish-dark"
                              : "bg-bearish-light text-bearish-dark"
                          }`}
                        >
                          {tx.transaction_type}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-right font-medium text-zinc-900 dark:text-zinc-100">{fmt(tx.quantity)}</td>
                      <td className="px-4 py-3 text-right text-zinc-600 dark:text-zinc-400">${fmt(tx.price_per_share)}</td>
                      <td className="px-4 py-3 text-right font-medium text-zinc-900 dark:text-zinc-100">${fmt(tx.total_amount)}</td>
                    </tr>
                    {expandedId === tx.id && (
                      <tr key={`${tx.id}-detail`} className="bg-zinc-50 dark:bg-zinc-700/50">
                        <td colSpan={6} className="px-4 py-4">
                          <div className="grid grid-cols-2 gap-4 text-sm sm:grid-cols-4">
                            <div>
                              <span className="text-zinc-500 dark:text-zinc-400">Transaction ID</span>
                              <p className="mt-0.5 font-mono text-xs text-zinc-700 dark:text-zinc-300">{tx.id}</p>
                            </div>
                            <div>
                              <span className="text-zinc-500 dark:text-zinc-400">Executed At</span>
                              <p className="mt-0.5 text-zinc-900 dark:text-zinc-100">{new Date(tx.executed_at).toLocaleString()}</p>
                            </div>
                            {tx.recommendation_at_time && (
                              <div>
                                <span className="text-zinc-500 dark:text-zinc-400">Recommendation</span>
                                <p className="mt-0.5 text-zinc-900 dark:text-zinc-100">{tx.recommendation_at_time}</p>
                              </div>
                            )}
                            {tx.notes && (
                              <div className="col-span-2">
                                <span className="text-zinc-500 dark:text-zinc-400">Notes</span>
                                <p className="mt-0.5 text-zinc-900 dark:text-zinc-100">{tx.notes}</p>
                              </div>
                            )}
                            <div>
                              <span className="text-zinc-500 dark:text-zinc-400">Created</span>
                              <p className="mt-0.5 text-zinc-900 dark:text-zinc-100">{new Date(tx.inserted_at).toLocaleString()}</p>
                            </div>
                          </div>
                        </td>
                      </tr>
                    )}
                  </Fragment>
                ))}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="mt-4 flex items-center justify-between">
              <p className="text-sm text-zinc-500 dark:text-zinc-400">
                Page {page} of {totalPages}
              </p>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                  disabled={page <= 1}
                  className="rounded-lg border border-zinc-300 px-3 py-1.5 text-sm font-medium text-zinc-700 transition-colors hover:bg-zinc-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-zinc-600 dark:bg-zinc-800 dark:text-zinc-200 dark:hover:bg-zinc-700"
                >
                  Previous
                </button>
                <button
                  type="button"
                  onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                  disabled={page >= totalPages}
                  className="rounded-lg border border-zinc-300 px-3 py-1.5 text-sm font-medium text-zinc-700 transition-colors hover:bg-zinc-50 disabled:cursor-not-allowed disabled:opacity-50 dark:border-zinc-600 dark:bg-zinc-800 dark:text-zinc-200 dark:hover:bg-zinc-700"
                >
                  Next
                </button>
              </div>
            </div>
          )}
        </>
      ) : (
        <div className="mt-6 flex flex-col items-center rounded-xl border border-zinc-200 bg-white py-12 text-center shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
          <p className="text-zinc-500 dark:text-zinc-400">
            {tickerFilter || typeFilter ? "No transactions match your filters" : "No transactions yet"}
          </p>
          <p className="mt-1 text-sm text-zinc-400 dark:text-zinc-500">
            {tickerFilter || typeFilter
              ? "Try adjusting your filters"
              : "Execute your first trade from a stock page"}
          </p>
        </div>
      )}
    </div>
  );
}

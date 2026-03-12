"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useAuth } from "@/lib/auth-context";
import { stocksApi, paperTradingApi, engagementApi } from "@/lib/api";
import type {
  TrendingStock,
  PaperPortfolio,
  EnrichedHolding,
  PortfolioPerformance,
  WatchlistItem,
  HistoryEntry,
  StockOverview,
} from "@repo/types";

function fmt(value: string | null | undefined): string {
  if (value == null) return "—";
  const n = parseFloat(value);
  if (Number.isNaN(n)) return "—";
  return n.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function fmtDollar(value: string | null | undefined): string {
  if (value == null) return "$—";
  const n = parseFloat(value);
  if (Number.isNaN(n)) return "$—";
  return `${n >= 0 ? "+$" : "-$"}${Math.abs(n).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function fmtPct(value: string | null | undefined): string {
  if (value == null) return "—";
  const n = parseFloat(value);
  if (Number.isNaN(n)) return "—";
  return `${n >= 0 ? "+" : ""}${n.toFixed(2)}%`;
}

function colorCls(value: string | null | undefined): string {
  if (value == null) return "text-gray-500";
  const n = parseFloat(value);
  if (Number.isNaN(n)) return "text-gray-500";
  return n > 0 ? "text-bullish" : n < 0 ? "text-bearish" : "text-gray-500";
}

interface WatchlistRow extends WatchlistItem {
  price?: number | null;
  change?: number | null;
  change_percent?: string | null;
  name?: string | null;
}

export default function DashboardPage() {
  const { user } = useAuth();

  const [trending, setTrending] = useState<TrendingStock[]>([]);
  const [trendingLoading, setTrendingLoading] = useState(true);

  const [portfolio, setPortfolio] = useState<PaperPortfolio | null>(null);
  const [holdings, setHoldings] = useState<EnrichedHolding[]>([]);
  const [performance, setPerformance] = useState<PortfolioPerformance | null>(null);
  const [portfolioLoading, setPortfolioLoading] = useState(true);

  const [watchlist, setWatchlist] = useState<WatchlistRow[]>([]);
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [watchlistLoading, setWatchlistLoading] = useState(true);

  useEffect(() => {
    stocksApi
      .getTrending()
      .then(setTrending)
      .catch(() => setTrending([]))
      .finally(() => setTrendingLoading(false));
  }, []);

  useEffect(() => {
    paperTradingApi
      .listPortfolios()
      .then(async (res) => {
        const list = res.data;
        if (list.length > 0) {
          const p = list[0]!;
          setPortfolio(p);
          const [h, perf] = await Promise.all([
            paperTradingApi.listHoldings(p.id),
            paperTradingApi.getPerformance(p.id),
          ]);
          setHoldings(h.data.slice(0, 5));
          setPerformance(perf.data);
        }
      })
      .catch(() => {})
      .finally(() => setPortfolioLoading(false));
  }, []);

  const loadWatchlist = useCallback(async () => {
    try {
      const [wl, hist] = await Promise.all([
        engagementApi.listWatchlist(),
        engagementApi.listHistory(),
      ]);
      setHistory(hist.data.slice(0, 8));
      const rows: WatchlistRow[] = wl.data.slice(0, 6).map((w) => ({ ...w }));

      const overviews = await Promise.allSettled(
        rows.map((r) => stocksApi.getStock(r.ticker)),
      );
      setWatchlist(
        rows.map((row, i) => {
          const result = overviews[i];
          if (result?.status === "fulfilled") {
            const ov = result.value as StockOverview;
            return { ...row, price: ov.price, change: ov.change, change_percent: ov.change_percent, name: ov.name ?? null };
          }
          return row;
        }),
      );
    } catch {
      // ignore
    } finally {
      setWatchlistLoading(false);
    }
  }, []);

  useEffect(() => {
    loadWatchlist();
  }, [loadWatchlist]);

  const totalValue = performance ? parseFloat(performance.total_value) : 0;
  const startingBalance = portfolio ? parseFloat(portfolio.starting_balance) : 100000;
  const totalReturnDollar = performance ? (totalValue - startingBalance).toFixed(2) : null;

  return (
    <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6">
      {/* Welcome */}
      <h1 className="text-2xl font-bold tracking-tight text-gray-900 sm:text-3xl">
        Welcome{user?.username ? `, ${user.username}` : ""}
      </h1>
      <p className="mt-1 text-gray-500">
        Here&apos;s your trading overview.
      </p>

      {/* Top row: Portfolio + Watchlist */}
      <div className="mt-8 grid gap-6 lg:grid-cols-5">
        {/* Portfolio Summary — takes 3 columns */}
        <section className="lg:col-span-3">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold text-gray-900">Portfolio</h2>
            <Link href="/portfolio" className="text-sm font-medium text-primary-600 hover:underline">
              View details →
            </Link>
          </div>

          {portfolioLoading ? (
            <div className="mt-3 h-52 animate-pulse rounded-xl bg-gray-100" />
          ) : portfolio && performance ? (
            <div className="mt-3 rounded-xl border border-gray-200 bg-white shadow-sm">
              <div className="border-b border-gray-100 p-5">
                <p className="text-xs font-medium uppercase tracking-wide text-gray-500">Total Value</p>
                <div className="mt-1 flex flex-wrap items-baseline gap-3">
                  <span className="text-2xl font-bold text-gray-900">
                    ${fmt(performance.total_value)}
                  </span>
                  <span className={`text-sm font-semibold ${colorCls(totalReturnDollar)}`}>
                    {fmtDollar(totalReturnDollar)} ({fmtPct(performance.total_return)})
                  </span>
                </div>
                <div className="mt-3 flex flex-wrap gap-5 text-sm text-gray-500">
                  <span>Cash <span className="ml-1 font-medium text-gray-900">${fmt(performance.cash_balance)}</span></span>
                  <span>Holdings <span className="ml-1 font-medium text-gray-900">${fmt(performance.holdings_value)}</span></span>
                  <span>Win rate <span className="ml-1 font-medium text-gray-900">{fmtPct(performance.win_rate).replace("+", "")}</span></span>
                </div>
              </div>
              {holdings.length > 0 ? (
                <div className="divide-y divide-gray-50">
                  {holdings.map((h) => (
                    <Link
                      key={h.id}
                      href={`/stocks/${encodeURIComponent(h.ticker)}`}
                      className="flex items-center justify-between px-5 py-3 transition-colors hover:bg-gray-50"
                    >
                      <div>
                        <span className="font-semibold text-gray-900">{h.ticker}</span>
                        <span className="ml-2 text-sm text-gray-500">{fmt(h.quantity)} shares</span>
                      </div>
                      <div className="text-right">
                        <span className="font-medium text-gray-900">${fmt(h.current_value)}</span>
                        <span className={`ml-2 text-sm ${colorCls(h.gain_loss_percent)}`}>
                          {fmtPct(h.gain_loss_percent)}
                        </span>
                      </div>
                    </Link>
                  ))}
                </div>
              ) : (
                <div className="px-5 py-6 text-center text-sm text-gray-400">
                  No holdings yet — find a stock and place a trade.
                </div>
              )}
            </div>
          ) : (
            <div className="mt-3 rounded-xl border border-gray-200 bg-white p-8 text-center shadow-sm">
              <p className="font-medium text-gray-700">No portfolio yet</p>
              <p className="mt-1 text-sm text-gray-500">Create one to start paper trading.</p>
              <Link
                href="/portfolio"
                className="mt-4 inline-block rounded-lg bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700"
              >
                Create Portfolio
              </Link>
            </div>
          )}
        </section>

        {/* Watchlist — takes 2 columns */}
        <section className="lg:col-span-2">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold text-gray-900">Watchlist</h2>
            <Link href="/watchlist" className="text-sm font-medium text-primary-600 hover:underline">
              View all →
            </Link>
          </div>

          {watchlistLoading ? (
            <div className="mt-3 h-52 animate-pulse rounded-xl bg-gray-100" />
          ) : watchlist.length > 0 ? (
            <div className="mt-3 divide-y divide-gray-50 rounded-xl border border-gray-200 bg-white shadow-sm">
              {watchlist.map((item) => (
                <Link
                  key={item.id}
                  href={`/stocks/${encodeURIComponent(item.ticker)}`}
                  className="flex items-center justify-between px-5 py-3 transition-colors hover:bg-gray-50"
                >
                  <div>
                    <span className="font-semibold text-gray-900">{item.ticker}</span>
                    {item.name && (
                      <span className="ml-2 text-sm text-gray-400">{item.name}</span>
                    )}
                  </div>
                  <div className="text-right">
                    <span className="font-medium text-gray-900">
                      {item.price != null ? `$${item.price.toFixed(2)}` : "—"}
                    </span>
                    {item.change != null && (
                      <span className={`ml-2 text-sm ${item.change >= 0 ? "text-bullish" : "text-bearish"}`}>
                        {item.change >= 0 ? "+" : ""}{item.change.toFixed(2)}
                      </span>
                    )}
                  </div>
                </Link>
              ))}
            </div>
          ) : (
            <div className="mt-3 rounded-xl border border-gray-200 bg-white p-8 text-center shadow-sm">
              <p className="text-2xl">☆</p>
              <p className="mt-2 font-medium text-gray-700">Watchlist empty</p>
              <p className="mt-1 text-sm text-gray-500">Star stocks to track them here.</p>
            </div>
          )}
        </section>
      </div>

      {/* Recently Viewed */}
      {history.length > 0 && (
        <section className="mt-8">
          <h2 className="text-lg font-semibold text-gray-900">Recently viewed</h2>
          <div className="mt-3 flex flex-wrap gap-2">
            {history.map((h) => (
              <Link
                key={h.id}
                href={`/stocks/${encodeURIComponent(h.ticker)}`}
                className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-700 transition-colors hover:border-primary-300 hover:bg-primary-50 hover:text-primary-700"
              >
                {h.ticker}
              </Link>
            ))}
          </div>
        </section>
      )}

      {/* Trending */}
      <section className="mt-8">
        <h2 className="text-lg font-semibold text-gray-900">Popular stocks</h2>
        {trendingLoading ? (
          <div className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-20 animate-pulse rounded-xl bg-gray-100" />
            ))}
          </div>
        ) : trending.length > 0 ? (
          <ul className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {trending.map((stock) => (
              <li key={stock.ticker}>
                <Link
                  href={`/stocks/${encodeURIComponent(stock.ticker)}`}
                  className="block rounded-xl border border-gray-200 bg-white p-4 shadow-sm transition-colors hover:border-primary-300 hover:bg-gray-50"
                >
                  <div className="flex items-center justify-between">
                    <div>
                      <span className="font-semibold text-gray-900">{stock.ticker}</span>
                      <p className="text-sm text-gray-500">{stock.name}</p>
                    </div>
                    <div className="text-right">
                      <span className="font-medium text-gray-900">
                        ${stock.price != null ? stock.price.toFixed(2) : "—"}
                      </span>
                      <p className={`text-sm ${(stock.change ?? 0) >= 0 ? "text-bullish" : "text-bearish"}`}>
                        {(stock.change ?? 0) >= 0 ? "+" : ""}
                        {stock.change != null ? stock.change.toFixed(2) : "—"}{" "}
                        ({stock.change_percent ?? "—"})
                      </p>
                    </div>
                  </div>
                </Link>
              </li>
            ))}
          </ul>
        ) : (
          <p className="mt-3 text-sm text-gray-500">No trending data right now.</p>
        )}
      </section>
    </div>
  );
}

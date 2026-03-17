"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import type { WatchlistItem, HistoryEntry, StockOverview } from "@repo/types";
import { engagementApi, stocksApi } from "@/lib/api";

interface WatchlistRow extends WatchlistItem {
  price?: number | null;
  change?: number | null;
  change_percent?: string | null;
  name?: string | null;
}

export default function WatchlistPage() {
  const [items, setItems] = useState<WatchlistRow[]>([]);
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [removing, setRemoving] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const [wl, hist] = await Promise.all([
        engagementApi.listWatchlist(),
        engagementApi.listHistory(),
      ]);
      setHistory(hist.data.slice(0, 10));

      const rows: WatchlistRow[] = wl.data.map((w) => ({ ...w }));
      setItems(rows);

      const overviews = await Promise.allSettled(
        rows.map((r) => stocksApi.getStock(r.ticker)),
      );
      setItems((prev) =>
        prev.map((row, i) => {
          const result = overviews[i];
          if (result?.status === "fulfilled") {
            const ov = result.value as StockOverview;
            return {
              ...row,
              price: ov.price,
              change: ov.change,
              change_percent: ov.change_percent,
              name: ov.name ?? null,
            };
          }
          return row;
        }),
      );
    } catch {
      // silently ignore
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const handleRemove = async (ticker: string) => {
    setRemoving(ticker);
    try {
      await engagementApi.removeFromWatchlist(ticker);
      setItems((prev) => prev.filter((i) => i.ticker !== ticker));
    } catch {
      // ignore
    } finally {
      setRemoving(null);
    }
  };

  if (loading) {
    return (
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
        <h1 className="mb-6 text-2xl font-bold text-zinc-900 dark:text-zinc-100">Watchlist</h1>
        <div className="space-y-3">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-16 animate-pulse rounded-lg bg-zinc-100 dark:bg-zinc-700" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
      <h1 className="mb-6 text-2xl font-bold text-zinc-900 dark:text-zinc-100">Watchlist</h1>

      {items.length === 0 ? (
        <div className="rounded-xl border border-zinc-200 bg-white p-12 text-center shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
          <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-primary-50 dark:bg-primary-900/30">
            <svg className="h-8 w-8 text-primary-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M11.48 3.499a.562.562 0 0 1 1.04 0l2.125 5.111a.563.563 0 0 0 .475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 0 0-.182.557l1.285 5.385a.562.562 0 0 1-.84.61l-4.725-2.885a.562.562 0 0 0-.586 0L6.982 20.54a.562.562 0 0 1-.84-.61l1.285-5.386a.562.562 0 0 0-.182-.557l-4.204-3.602a.562.562 0 0 1 .321-.988l5.518-.442a.563.563 0 0 0 .475-.345L11.48 3.5Z" />
            </svg>
          </div>
          <h2 className="text-lg font-semibold text-zinc-900 dark:text-zinc-100">No stocks in your watchlist</h2>
          <p className="mt-2 text-zinc-500 dark:text-zinc-400">
            Add stocks to your watchlist from any analysis page to track them here.
          </p>
          <Link
            href="/dashboard"
            className="mt-6 inline-block rounded-lg bg-primary-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-700"
          >
            Browse stocks
          </Link>
        </div>
      ) : (
        <div className="overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm dark:border-zinc-700 dark:bg-zinc-800">
          <table className="w-full">
            <thead>
              <tr className="border-b border-zinc-100 bg-zinc-50/50 text-left text-xs font-medium uppercase tracking-wider text-zinc-500 dark:border-zinc-700 dark:bg-zinc-700/50 dark:text-zinc-400">
                <th className="px-4 py-3">Ticker</th>
                <th className="px-4 py-3">Name</th>
                <th className="px-4 py-3 text-right">Price</th>
                <th className="px-4 py-3 text-right">Change</th>
                <th className="px-4 py-3 text-right">Added</th>
                <th className="px-4 py-3" />
              </tr>
            </thead>
            <tbody>
              {items.map((item) => (
                <tr
                  key={item.id}
                  className="border-b border-zinc-50 transition-colors hover:bg-zinc-50 dark:border-zinc-700 dark:hover:bg-zinc-700/50"
                >
                  <td className="px-4 py-3">
                    <Link
                      href={`/stocks/${encodeURIComponent(item.ticker)}`}
                      className="font-semibold text-primary-600 hover:underline dark:text-primary-400"
                    >
                      {item.ticker}
                    </Link>
                  </td>
                  <td className="px-4 py-3 text-sm text-zinc-600 dark:text-zinc-400">
                    {item.name ?? "—"}
                  </td>
                  <td className="px-4 py-3 text-right font-medium text-zinc-900 dark:text-zinc-100">
                    {item.price != null ? `$${item.price.toFixed(2)}` : "—"}
                  </td>
                  <td className="px-4 py-3 text-right">
                    {item.change != null ? (
                      <span className={item.change >= 0 ? "text-bullish" : "text-bearish"}>
                        {item.change >= 0 ? "+" : ""}{item.change.toFixed(2)}
                        {item.change_percent ? ` (${item.change_percent})` : ""}
                      </span>
                    ) : (
                      "—"
                    )}
                  </td>
                  <td className="px-4 py-3 text-right text-sm text-zinc-400 dark:text-zinc-500">
                    {new Date(item.added_at).toLocaleDateString()}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <button
                      type="button"
                      onClick={() => handleRemove(item.ticker)}
                      disabled={removing === item.ticker}
                      className="text-sm text-zinc-400 transition-colors hover:text-bearish disabled:opacity-50"
                    >
                      {removing === item.ticker ? "..." : "Remove"}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {history.length > 0 && (
        <section className="mt-10">
          <h2 className="mb-4 text-lg font-semibold text-zinc-900 dark:text-zinc-100">Recently viewed</h2>
          <div className="flex flex-wrap gap-2">
            {history.map((h) => (
              <Link
                key={h.id}
                href={`/stocks/${encodeURIComponent(h.ticker)}`}
                className="rounded-lg border border-zinc-200 bg-white px-4 py-2 text-sm font-medium text-zinc-700 transition-colors hover:border-primary-300 hover:bg-primary-50 hover:text-primary-700 dark:border-zinc-600 dark:bg-zinc-800 dark:text-zinc-200 dark:hover:border-primary-600 dark:hover:bg-primary-900/30 dark:hover:text-primary-300"
              >
                {h.ticker}
              </Link>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}

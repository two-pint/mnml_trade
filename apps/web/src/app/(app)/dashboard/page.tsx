"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useAuth } from "@/lib/auth-context";
import { stocksApi } from "@/lib/api";
import type { TrendingStock } from "@repo/types";

export default function DashboardPage() {
  const { user } = useAuth();
  const [trending, setTrending] = useState<TrendingStock[]>([]);
  const [trendingLoading, setTrendingLoading] = useState(true);

  useEffect(() => {
    stocksApi
      .getTrending()
      .then(setTrending)
      .catch(() => setTrending([]))
      .finally(() => setTrendingLoading(false));
  }, []);

  return (
    <div className="flex flex-1 flex-col px-4 py-8 sm:px-6">
      <div className="mx-auto w-full max-w-4xl">
        <h2 className="text-2xl font-bold tracking-tight text-gray-900 sm:text-3xl">
          Welcome{user?.username ? `, ${user.username}` : ""}
        </h2>
        <p className="mt-2 text-gray-500">
          Use the search bar to find a stock or pick one below.
        </p>

        <section className="mt-8">
          <h3 className="text-lg font-semibold text-gray-900">Popular stocks</h3>
          {trendingLoading ? (
            <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {[1, 2, 3].map((i) => (
                <div key={i} className="h-24 animate-pulse rounded-xl bg-gray-100" />
              ))}
            </div>
          ) : trending.length > 0 ? (
            <ul className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
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
                        <p
                          className={`text-sm ${
                            (stock.change ?? 0) >= 0 ? "text-bullish" : "text-bearish"
                          }`}
                        >
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
            <p className="mt-4 text-sm text-gray-500">No trending data right now.</p>
          )}
        </section>
      </div>
    </div>
  );
}

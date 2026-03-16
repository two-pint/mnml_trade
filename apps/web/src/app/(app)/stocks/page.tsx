"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import type { MarketNewsArticle } from "@repo/types";
import { stocksApi } from "@/lib/api";
import { StockSearch } from "@/components/stock-search";

function formatTime(ts: number | null): string {
  if (ts == null) return "";
  const d = new Date(ts * 1000);
  const now = new Date();
  const sameDay = d.toDateString() === now.toDateString();
  if (sameDay) return d.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });
}

function NewsCard({ article }: { article: MarketNewsArticle }) {
  return (
    <article className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm transition-shadow hover:shadow-md">
      <div className="mb-2 flex items-center gap-2 text-xs text-gray-500">
        {article.source && <span className="font-medium text-gray-600">{article.source}</span>}
        {article.datetime != null && <span>{formatTime(article.datetime)}</span>}
      </div>
      {article.url ? (
        <a
          href={article.url}
          target="_blank"
          rel="noopener noreferrer"
          className="block text-sm font-semibold text-gray-900 hover:text-primary-600 line-clamp-2"
        >
          {article.headline ?? "Untitled"}
        </a>
      ) : (
        <p className="text-sm font-semibold text-gray-900 line-clamp-2">{article.headline ?? "Untitled"}</p>
      )}
      {article.summary && (
        <p className="mt-2 text-xs text-gray-600 line-clamp-2">{article.summary}</p>
      )}
    </article>
  );
}

export default function StocksPage() {
  const [news, setNews] = useState<MarketNewsArticle[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    stocksApi
      .getMarketNews()
      .then(setNews)
      .catch(() => setNews([]))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6">
      <div className="mb-8">
        <h1 className="mb-2 text-2xl font-bold text-gray-900">Stocks</h1>
        <p className="mb-6 text-gray-600">
          Market-wide news and research. Search for a symbol to dive into a stock.
        </p>
        <div className="max-w-md">
          <StockSearch />
        </div>
      </div>

      <section>
        <h2 className="mb-4 text-lg font-semibold text-gray-800">Market news</h2>
        {loading ? (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {[1, 2, 3, 4, 5, 6].map((i) => (
              <div key={i} className="h-32 animate-pulse rounded-xl bg-gray-100" />
            ))}
          </div>
        ) : news.length === 0 ? (
          <p className="rounded-xl border border-gray-200 bg-gray-50 p-8 text-center text-sm text-gray-500">
            No market news available. Check that FINNHUB_API_KEY is set for news.
          </p>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {news.map((article, i) => (
              <NewsCard key={i} article={article} />
            ))}
          </div>
        )}
      </section>

      <section className="mt-10 rounded-xl border border-gray-200 bg-gray-50/50 p-6">
        <h2 className="mb-3 text-sm font-semibold text-gray-700">Quick lookups</h2>
        <ul className="flex flex-wrap gap-3 text-sm">
          {["AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "META", "TSLA"].map((ticker) => (
            <li key={ticker}>
              <Link href={`/stocks/${ticker}`} className="text-primary-600 hover:underline">
                {ticker}
              </Link>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}

"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import type { SentimentAnalysis, SentimentPost, SentimentNewsArticle, InstitutionalData } from "@repo/types";
import { stocksApi } from "@/lib/api";

function SentimentGauge({ score, label }: { score: number; label: string }) {
  const clampedScore = Math.max(-100, Math.min(100, score));
  const normalized = (clampedScore + 100) / 200;
  const rotation = -90 + normalized * 180;

  const gaugeColor =
    label === "Bullish" ? "text-bullish" :
    label === "Bearish" ? "text-bearish" :
    "text-zinc-500";

  const bgColor =
    label === "Bullish" ? "bg-bullish-light text-bullish-dark" :
    label === "Bearish" ? "bg-bearish-light text-bearish-dark" :
    "bg-zinc-100 text-zinc-700 dark:bg-zinc-700 dark:text-zinc-200";

  return (
    <div className="flex flex-col items-center">
      <div className="relative h-28 w-56 overflow-hidden">
        {/* Gauge background arc */}
        <div className="absolute bottom-0 left-0 right-0 h-28 w-56">
          <svg viewBox="0 0 200 100" className="h-full w-full">
            <defs>
              <linearGradient id="gaugeGrad" x1="0%" y1="0%" x2="100%" y2="0%">
                <stop offset="0%" stopColor="var(--color-bearish)" />
                <stop offset="50%" stopColor="#94a3b8" />
                <stop offset="100%" stopColor="var(--color-bullish)" />
              </linearGradient>
            </defs>
            <path
              d="M 10 95 A 90 90 0 0 1 190 95"
              fill="none"
              stroke="url(#gaugeGrad)"
              strokeWidth="12"
              strokeLinecap="round"
            />
            {/* Needle */}
            <g transform={`rotate(${rotation}, 100, 95)`}>
              <line x1="100" y1="95" x2="100" y2="15" stroke="#1f2937" strokeWidth="2.5" strokeLinecap="round" />
              <circle cx="100" cy="95" r="5" fill="#1f2937" />
            </g>
          </svg>
        </div>
      </div>
      <div className="mt-2 flex items-center gap-2">
        <span className={`text-3xl font-bold ${gaugeColor}`}>{score}</span>
        <span className={`rounded-full px-3 py-1 text-sm font-medium ${bgColor}`}>{label}</span>
      </div>
      <div className="mt-1 flex w-full justify-between px-2 text-xs text-zinc-400">
        <span>Very Bearish</span>
        <span>Very Bullish</span>
      </div>
    </div>
  );
}

function SentimentBadge({ sentiment }: { sentiment: string }) {
  const cls =
    sentiment === "bullish" ? "bg-bullish-light text-bullish-dark" :
    sentiment === "bearish" ? "bg-bearish-light text-bearish-dark" :
    "bg-zinc-100 text-zinc-600 dark:bg-zinc-600 dark:text-zinc-200";
  return (
    <span className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium capitalize ${cls}`}>
      {sentiment}
    </span>
  );
}

function PostCard({ post }: { post: SentimentPost }) {
  const timeAgo = post.created_utc
    ? formatTimeAgo(post.created_utc * 1000)
    : null;

  return (
    <div className="rounded-lg border border-zinc-100 bg-zinc-50/50 dark:border-zinc-700 dark:bg-zinc-700/50 p-4">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <div className="mb-1 flex items-center gap-2 text-xs text-zinc-400">
            <span className="font-medium text-zinc-500 dark:text-zinc-400">r/{post.subreddit}</span>
            {timeAgo && <span>· {timeAgo}</span>}
          </div>
          {post.url ? (
            <a href={post.url} target="_blank" rel="noopener noreferrer" className="text-sm font-medium text-zinc-900 dark:text-zinc-100 hover:text-primary-600 line-clamp-2">
              {post.title}
            </a>
          ) : (
            <p className="text-sm font-medium text-zinc-900 dark:text-zinc-100 line-clamp-2">{post.title}</p>
          )}
        </div>
        <SentimentBadge sentiment={post.sentiment} />
      </div>
      <div className="mt-2 flex items-center gap-4 text-xs text-zinc-400">
        <span>↑ {post.score}</span>
        <span>{post.num_comments} comments</span>
      </div>
    </div>
  );
}

function NewsCard({ article }: { article: SentimentNewsArticle }) {
  const date = article.datetime
    ? new Date(article.datetime * 1000).toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
      })
    : null;

  return (
    <div className="flex items-start justify-between gap-3 rounded-lg border border-zinc-100 bg-zinc-50/50 dark:border-zinc-700 dark:bg-zinc-700/50 p-4">
      <div className="min-w-0 flex-1">
        <div className="mb-1 flex items-center gap-2 text-xs text-zinc-400">
          {article.source && <span className="font-medium text-zinc-500 dark:text-zinc-400">{article.source}</span>}
          {date && <span>· {date}</span>}
        </div>
        {article.url ? (
          <a href={article.url} target="_blank" rel="noopener noreferrer" className="text-sm font-medium text-zinc-900 dark:text-zinc-100 hover:text-primary-600 line-clamp-2">
            {article.headline ?? "Untitled"}
          </a>
        ) : (
          <p className="text-sm font-medium text-zinc-900 dark:text-zinc-100 line-clamp-2">{article.headline ?? "Untitled"}</p>
        )}
        {article.summary && (
          <p className="mt-1 text-xs text-zinc-500 dark:text-zinc-400 line-clamp-2">{article.summary}</p>
        )}
      </div>
      <SentimentBadge sentiment={article.sentiment} />
    </div>
  );
}

function SmartMoneyBrief({ ticker, tabSetter }: { ticker: string; tabSetter: (id: string) => string }) {
  const [instData, setInstData] = useState<InstitutionalData | null>(null);

  useEffect(() => {
    stocksApi
      .getStockInstitutional(ticker)
      .then(setInstData)
      .catch(() => {});
  }, [ticker]);

  if (!instData) return null;

  const flowCount = instData.options_flow?.length ?? 0;
  const bullishCount = instData.options_flow?.filter((t) => t.sentiment?.toLowerCase() === "bullish").length ?? 0;
  const dpVolume = instData.dark_pool?.volume;

  return (
    <div className="rounded-lg border border-zinc-100 bg-zinc-50/50 dark:border-zinc-700 dark:bg-zinc-700/50 p-4">
      <div className="flex items-center justify-between">
        <h4 className="text-sm font-semibold text-zinc-700 dark:text-zinc-300">Smart Money Snapshot</h4>
        <Link href={tabSetter("institutional")} className="text-xs text-primary-600 hover:underline">
          View full →
        </Link>
      </div>
      <div className="mt-3 grid grid-cols-3 gap-3 text-center">
        <div>
          <p className="text-lg font-semibold text-zinc-900 dark:text-zinc-100">{flowCount}</p>
          <p className="text-xs text-zinc-500 dark:text-zinc-400">Options Alerts</p>
        </div>
        <div>
          <p className="text-lg font-semibold text-bullish">
            {flowCount > 0 ? Math.round((bullishCount / flowCount) * 100) : 0}%
          </p>
          <p className="text-xs text-zinc-500 dark:text-zinc-400">Bullish Flow</p>
        </div>
        <div>
          <p className="text-lg font-semibold text-zinc-900 dark:text-zinc-100">
            {dpVolume != null ? formatCompact(dpVolume) : "—"}
          </p>
          <p className="text-xs text-zinc-500 dark:text-zinc-400">Dark Pool Vol</p>
        </div>
      </div>
    </div>
  );
}

function formatTimeAgo(ms: number): string {
  const diff = Date.now() - ms;
  const hours = Math.floor(diff / 3_600_000);
  if (hours < 1) return "< 1h ago";
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days === 1) return "1d ago";
  return `${days}d ago`;
}

function formatCompact(n: number): string {
  const abs = Math.abs(n);
  if (abs >= 1e9) return `${(n / 1e9).toFixed(1)}B`;
  if (abs >= 1e6) return `${(n / 1e6).toFixed(1)}M`;
  if (abs >= 1e3) return `${(n / 1e3).toFixed(0)}K`;
  return n.toString();
}

export default function EmotionalTab({
  ticker,
  tabSetter,
}: {
  ticker: string;
  tabSetter: (id: string) => string;
}) {
  const [data, setData] = useState<SentimentAnalysis | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  useEffect(() => {
    if (!ticker) return;
    setLoading(true);
    setError(false);
    stocksApi
      .getStockSentiment(ticker)
      .then(setData)
      .catch(() => setError(true))
      .finally(() => setLoading(false));
  }, [ticker]);

  if (loading) {
    return (
      <section className="mt-6 space-y-4">
        <div className="h-44 animate-pulse rounded-xl bg-zinc-100 dark:bg-zinc-700" />
        <div className="h-40 animate-pulse rounded-xl bg-zinc-100 dark:bg-zinc-700" />
        <div className="h-40 animate-pulse rounded-xl bg-zinc-100 dark:bg-zinc-700" />
      </section>
    );
  }

  if (error || !data) {
    return (
      <section className="mt-6 rounded-xl border border-zinc-200 bg-white dark:border-zinc-700 dark:bg-zinc-800 p-12 text-center shadow-sm">
        <p className="text-zinc-500 dark:text-zinc-400">Sentiment data unavailable</p>
      </section>
    );
  }

  const trendIcon =
    data.trend === "improving" ? "↑" :
    data.trend === "declining" ? "↓" : "→";
  const trendColor =
    data.trend === "improving" ? "text-bullish" :
    data.trend === "declining" ? "text-bearish" : "text-zinc-500 dark:text-zinc-400";

  return (
    <section className="mt-6 space-y-6">
      {/* Sentiment Overview */}
      <div className="rounded-xl border border-zinc-200 bg-white dark:border-zinc-700 dark:bg-zinc-800 p-6 shadow-sm">
        <SentimentGauge score={data.score} label={data.label} />
        <div className="mt-4 flex justify-center gap-8">
          <div className="text-center">
            <span className={`text-lg font-semibold ${trendColor}`}>{trendIcon}</span>
            <p className="text-xs text-zinc-500 dark:text-zinc-400">Trend: <span className="capitalize">{data.trend}</span></p>
          </div>
          <div className="text-center">
            <span className="text-lg font-semibold text-zinc-900 dark:text-zinc-100">{data.mention_count}</span>
            <p className="text-xs text-zinc-500 dark:text-zinc-400">Mentions</p>
          </div>
        </div>
      </div>

      {/* Reddit Posts */}
      {data.top_posts.length > 0 && (
        <div className="rounded-xl border border-zinc-200 bg-white dark:border-zinc-700 dark:bg-zinc-800 p-6 shadow-sm">
          <h3 className="mb-4 text-sm font-semibold text-zinc-700 dark:text-zinc-300">Reddit Sentiment</h3>
          <div className="space-y-3">
            {data.top_posts.slice(0, 5).map((post, i) => (
              <PostCard key={i} post={post} />
            ))}
          </div>
        </div>
      )}

      {/* News */}
      {data.news.length > 0 && (
        <div className="rounded-xl border border-zinc-200 bg-white dark:border-zinc-700 dark:bg-zinc-800 p-6 shadow-sm">
          <h3 className="mb-4 text-sm font-semibold text-zinc-700 dark:text-zinc-300">News Sentiment</h3>
          <div className="space-y-3">
            {data.news.slice(0, 5).map((article, i) => (
              <NewsCard key={i} article={article} />
            ))}
          </div>
        </div>
      )}

      {/* Smart Money Brief */}
      <div className="rounded-xl border border-zinc-200 bg-white dark:border-zinc-700 dark:bg-zinc-800 p-6 shadow-sm">
        <SmartMoneyBrief ticker={ticker} tabSetter={tabSetter} />
      </div>
    </section>
  );
}

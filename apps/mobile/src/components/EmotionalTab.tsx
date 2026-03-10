import { useEffect, useState } from "react";
import {
  View,
  Text,
  ActivityIndicator,
  TouchableOpacity,
  Linking,
} from "react-native";
import type { SentimentAnalysis, SentimentPost, SentimentNewsArticle } from "@repo/types";
import { stocksApi } from "@/lib/api";

function formatTimeAgo(ms: number): string {
  const diff = Date.now() - ms;
  const hours = Math.floor(diff / 3_600_000);
  if (hours < 1) return "< 1h ago";
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days === 1) return "1d ago";
  return `${days}d ago`;
}

function SentimentBadge({ sentiment }: { sentiment: string }) {
  const cls =
    sentiment === "bullish"
      ? "bg-green-100 text-green-800"
      : sentiment === "bearish"
        ? "bg-red-100 text-red-800"
        : "bg-gray-100 text-gray-600";
  return (
    <View className={`rounded-full px-2 py-0.5 ${cls}`}>
      <Text className="text-xs font-medium capitalize">{sentiment}</Text>
    </View>
  );
}

function GaugeBar({ score }: { score: number }) {
  const normalized = Math.max(0, Math.min(100, (score + 100) / 2));
  const color =
    score > 25
      ? "bg-green-500"
      : score < -25
        ? "bg-red-500"
        : "bg-gray-400";

  return (
    <View className="mt-2">
      <View className="h-3 w-full rounded-full bg-gray-200">
        <View
          className={`h-full rounded-full ${color}`}
          style={{ width: `${normalized}%` }}
        />
      </View>
      <View className="mt-1 flex-row justify-between">
        <Text className="text-[10px] text-gray-400">Very Bearish</Text>
        <Text className="text-[10px] text-gray-400">Very Bullish</Text>
      </View>
    </View>
  );
}

function PostCard({ post }: { post: SentimentPost }) {
  const timeAgo = post.created_utc ? formatTimeAgo(post.created_utc * 1000) : null;

  return (
    <TouchableOpacity
      className="rounded-lg border border-gray-100 bg-gray-50 p-3"
      activeOpacity={post.url ? 0.7 : 1}
      onPress={post.url ? () => Linking.openURL(post.url!) : undefined}
    >
      <View className="flex-row items-start justify-between gap-2">
        <View className="flex-1">
          <View className="mb-1 flex-row items-center gap-2">
            <Text className="text-xs font-medium text-gray-500">
              r/{post.subreddit}
            </Text>
            {timeAgo && <Text className="text-xs text-gray-400">· {timeAgo}</Text>}
          </View>
          <Text className="text-sm font-medium text-gray-900" numberOfLines={2}>
            {post.title}
          </Text>
        </View>
        <SentimentBadge sentiment={post.sentiment} />
      </View>
      <View className="mt-2 flex-row gap-4">
        <Text className="text-xs text-gray-400">↑ {post.score}</Text>
        <Text className="text-xs text-gray-400">{post.num_comments} comments</Text>
      </View>
    </TouchableOpacity>
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
    <TouchableOpacity
      className="rounded-lg border border-gray-100 bg-gray-50 p-3"
      activeOpacity={article.url ? 0.7 : 1}
      onPress={article.url ? () => Linking.openURL(article.url!) : undefined}
    >
      <View className="flex-row items-start justify-between gap-2">
        <View className="flex-1">
          <View className="mb-1 flex-row items-center gap-2">
            {article.source && (
              <Text className="text-xs font-medium text-gray-500">{article.source}</Text>
            )}
            {date && <Text className="text-xs text-gray-400">· {date}</Text>}
          </View>
          <Text className="text-sm font-medium text-gray-900" numberOfLines={2}>
            {article.headline ?? "Untitled"}
          </Text>
          {article.summary && (
            <Text className="mt-1 text-xs text-gray-500" numberOfLines={2}>
              {article.summary}
            </Text>
          )}
        </View>
        <SentimentBadge sentiment={article.sentiment} />
      </View>
    </TouchableOpacity>
  );
}

export default function EmotionalTab({ ticker }: { ticker: string }) {
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
      <View className="items-center py-12">
        <ActivityIndicator size="small" color="#4c6ef5" />
      </View>
    );
  }

  if (error || !data) {
    return (
      <View className="items-center py-12">
        <Text className="text-gray-500">Sentiment data unavailable</Text>
      </View>
    );
  }

  const trendIcon =
    data.trend === "improving" ? "↑" : data.trend === "declining" ? "↓" : "→";
  const trendColor =
    data.trend === "improving"
      ? "text-green-600"
      : data.trend === "declining"
        ? "text-red-600"
        : "text-gray-500";

  const labelColor =
    data.label === "Bullish"
      ? "bg-green-100 text-green-800"
      : data.label === "Bearish"
        ? "bg-red-100 text-red-800"
        : "bg-gray-100 text-gray-700";

  return (
    <View className="gap-4 p-4">
      {/* Sentiment Overview */}
      <View className="items-center rounded-xl border border-gray-200 bg-white p-4">
        <Text className="text-sm text-gray-500">Sentiment Score</Text>
        <Text className="mt-1 text-3xl font-bold text-gray-900">{data.score}</Text>
        <View className={`mt-2 rounded-full px-3 py-1 ${labelColor}`}>
          <Text className="text-sm font-medium">{data.label}</Text>
        </View>
        <View className="mt-3 w-full px-4">
          <GaugeBar score={data.score} />
        </View>
        <View className="mt-3 flex-row gap-6">
          <View className="items-center">
            <Text className={`text-lg font-semibold ${trendColor}`}>{trendIcon}</Text>
            <Text className="text-xs text-gray-500 capitalize">{data.trend}</Text>
          </View>
          <View className="items-center">
            <Text className="text-lg font-semibold text-gray-900">{data.mention_count}</Text>
            <Text className="text-xs text-gray-500">Mentions</Text>
          </View>
        </View>
      </View>

      {/* Reddit Posts */}
      {data.top_posts.length > 0 && (
        <View className="rounded-xl border border-gray-200 bg-white p-4">
          <Text className="mb-3 text-sm font-semibold text-gray-700">Reddit Sentiment</Text>
          <View className="gap-2">
            {data.top_posts.slice(0, 5).map((post, i) => (
              <PostCard key={i} post={post} />
            ))}
          </View>
        </View>
      )}

      {/* News */}
      {data.news.length > 0 && (
        <View className="rounded-xl border border-gray-200 bg-white p-4">
          <Text className="mb-3 text-sm font-semibold text-gray-700">News Sentiment</Text>
          <View className="gap-2">
            {data.news.slice(0, 5).map((article, i) => (
              <NewsCard key={i} article={article} />
            ))}
          </View>
        </View>
      )}
    </View>
  );
}

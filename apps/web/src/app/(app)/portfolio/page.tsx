"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import type { PaperPortfolio } from "@repo/types";
import { paperTradingApi } from "@/lib/api";
import { CreatePortfolioForm } from "@/components/create-portfolio-form";

export default function PortfolioIndexPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [portfolios, setPortfolios] = useState<PaperPortfolio[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    paperTradingApi
      .listPortfolios()
      .then((res) => {
        const list = res.data;
        setPortfolios(list);
        if (list.length > 0) {
          router.replace(`/portfolio/${list[0]!.id}`);
        }
      })
      .catch(() => setError("Failed to load portfolios"))
      .finally(() => setLoading(false));
  }, [router]);

  if (loading || portfolios.length > 0) {
    return (
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
        <div className="h-8 w-48 animate-pulse rounded bg-zinc-100 dark:bg-zinc-700" />
        <div className="mt-6 h-32 animate-pulse rounded-xl bg-zinc-100 dark:bg-zinc-700" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
        <p className="text-bearish">{error}</p>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
      <h1 className="text-2xl font-bold text-zinc-900 dark:text-zinc-100">Paper trading</h1>
      <p className="mt-2 max-w-lg text-sm text-zinc-500 dark:text-zinc-400">
        Create a named portfolio and choose how much virtual cash to start with. You can add more portfolios anytime from the sidebar.
      </p>
      <div className="mt-10">
        <h2 className="text-lg font-semibold text-zinc-900 dark:text-zinc-100">Create your first portfolio</h2>
        <div className="mt-6">
          <CreatePortfolioForm />
        </div>
      </div>
    </div>
  );
}

"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { paperTradingApi } from "@/lib/api";
import { dispatchPortfoliosChanged } from "@/lib/portfolio-events";

type CreatePortfolioFormProps = {
  onSuccess?: (portfolioId: string) => void;
  submitLabel?: string;
};

export function CreatePortfolioForm({ onSuccess, submitLabel = "Create portfolio" }: CreatePortfolioFormProps) {
  const router = useRouter();
  const [name, setName] = useState("");
  const [startingBalance, setStartingBalance] = useState("100000");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    const trimmed = name.trim();
    const bal = parseFloat(startingBalance.replace(/,/g, ""));
    if (!trimmed) {
      setError("Enter a portfolio name.");
      return;
    }
    if (Number.isNaN(bal) || bal <= 0) {
      setError("Starting balance must be a positive number.");
      return;
    }
    setSubmitting(true);
    try {
      const res = await paperTradingApi.createPortfolio({
        name: trimmed,
        starting_balance: bal,
      });
      dispatchPortfoliosChanged();
      if (onSuccess) {
        onSuccess(res.data.id);
      } else {
        router.push(`/portfolio/${res.data.id}`);
      }
    } catch {
      setError("Failed to create portfolio.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="mx-auto w-full max-w-md space-y-4">
      <div>
        <label htmlFor="portfolio-name" className="block text-sm font-medium text-zinc-700 dark:text-zinc-300">
          Name
        </label>
        <input
          id="portfolio-name"
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="e.g. Growth practice"
          className="mt-1 w-full rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 placeholder:text-zinc-400 focus:border-primary-500 focus:outline-none focus:ring-2 focus:ring-primary-500/20 dark:border-zinc-600 dark:bg-zinc-800 dark:text-zinc-100"
          autoComplete="off"
        />
      </div>
      <div>
        <label htmlFor="portfolio-starting" className="block text-sm font-medium text-zinc-700 dark:text-zinc-300">
          Starting balance (paper money)
        </label>
        <input
          id="portfolio-starting"
          type="text"
          inputMode="decimal"
          value={startingBalance}
          onChange={(e) => setStartingBalance(e.target.value)}
          placeholder="100000"
          className="mt-1 w-full rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 placeholder:text-zinc-400 focus:border-primary-500 focus:outline-none focus:ring-2 focus:ring-primary-500/20 dark:border-zinc-600 dark:bg-zinc-800 dark:text-zinc-100"
        />
        <p className="mt-1 text-xs text-zinc-500 dark:text-zinc-400">Virtual cash available for paper trades.</p>
      </div>
      {error && (
        <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800 dark:border-red-900 dark:bg-red-950/40 dark:text-red-200">
          {error}
        </p>
      )}
      <button
        type="submit"
        disabled={submitting}
        className="w-full rounded-lg bg-primary-600 px-4 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-primary-700 disabled:opacity-50"
      >
        {submitting ? "Creating…" : submitLabel}
      </button>
    </form>
  );
}

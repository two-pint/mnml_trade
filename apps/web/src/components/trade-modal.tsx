"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import type { PaperPortfolio, TradeResult } from "@repo/types";
import { paperTradingApi } from "@/lib/api";
import { ApiClientError } from "@repo/api-client";

type Side = "buy" | "sell";

interface TradeModalProps {
  ticker: string;
  currentPrice: number | null;
  open: boolean;
  onClose: () => void;
}

export default function TradeModal({ ticker, currentPrice, open, onClose }: TradeModalProps) {
  const [side, setSide] = useState<Side>("buy");
  const [quantity, setQuantity] = useState("");
  const [portfolios, setPortfolios] = useState<PaperPortfolio[]>([]);
  const [selectedPortfolioId, setSelectedPortfolioId] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<TradeResult | null>(null);
  const [portfolioLoading, setPortfolioLoading] = useState(true);
  const backdropRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    setError(null);
    setResult(null);
    setQuantity("");
    setSide("buy");
    setPortfolioLoading(true);

    paperTradingApi
      .listPortfolios()
      .then((res) => {
        const list = res.data;
        setPortfolios(list);
        if (list.length > 0 && !selectedPortfolioId) {
          setSelectedPortfolioId(list[0]!.id);
        }
      })
      .catch(() => setError("Failed to load portfolios"))
      .finally(() => setPortfolioLoading(false));
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    document.addEventListener("keydown", handleEsc);
    return () => document.removeEventListener("keydown", handleEsc);
  }, [open, onClose]);

  const handleBackdropClick = useCallback(
    (e: React.MouseEvent) => {
      if (e.target === backdropRef.current) onClose();
    },
    [onClose],
  );

  const selectedPortfolio = portfolios.find((p) => p.id === selectedPortfolioId);
  const qty = parseInt(quantity, 10);
  const validQty = !Number.isNaN(qty) && qty >= 1 && qty <= 10_000;
  const totalCost = currentPrice != null && validQty ? qty * currentPrice : null;
  const cashAvailable = selectedPortfolio ? parseFloat(selectedPortfolio.cash_balance) : 0;

  const sharesOwned = selectedPortfolio?.holdings?.find(
    (h) => h.ticker.toUpperCase() === ticker.toUpperCase(),
  );
  const sharesQty = sharesOwned ? parseFloat(sharesOwned.quantity) : 0;

  const canSubmit =
    validQty &&
    currentPrice != null &&
    selectedPortfolioId != null &&
    !submitting &&
    !portfolioLoading;

  const validationError = (() => {
    if (!validQty && quantity !== "") {
      const n = parseInt(quantity, 10);
      if (Number.isNaN(n) || n < 1) return "Quantity must be at least 1";
      if (n > 10_000) return "Maximum 10,000 shares per trade";
    }
    if (side === "buy" && totalCost != null && totalCost > cashAvailable) {
      return `Insufficient cash — you have $${cashAvailable.toLocaleString("en-US", { minimumFractionDigits: 2 })}`;
    }
    if (side === "sell" && validQty && qty > sharesQty) {
      return `Insufficient shares — you own ${sharesQty} of ${ticker}`;
    }
    return null;
  })();

  const handleSubmit = async () => {
    if (!canSubmit || validationError) return;
    setSubmitting(true);
    setError(null);

    try {
      const res = await paperTradingApi.executeTrade(selectedPortfolioId!, {
        ticker,
        side,
        quantity: qty,
      });
      setResult(res.data);
    } catch (err) {
      if (err instanceof ApiClientError) {
        setError(err.error.message ?? err.message);
      } else {
        setError("Trade failed. Please try again.");
      }
    } finally {
      setSubmitting(false);
    }
  };

  if (!open) return null;

  return (
    <div
      ref={backdropRef}
      onClick={handleBackdropClick}
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4 backdrop-blur-sm"
    >
      <div className="w-full max-w-md rounded-2xl border border-zinc-200 bg-white shadow-xl dark:border-zinc-700 dark:bg-zinc-800">
        {/* Header */}
        <div className="flex items-center justify-between border-b border-zinc-100 px-6 py-4 dark:border-zinc-700">
          <h2 className="text-lg font-bold text-zinc-900 dark:text-zinc-100">Trade {ticker}</h2>
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg p-1 text-zinc-400 transition-colors hover:bg-zinc-100 hover:text-zinc-600 dark:hover:bg-zinc-700 dark:hover:text-zinc-200"
            aria-label="Close"
          >
            <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {result ? (
          /* Success State */
          <div className="px-6 py-8 text-center">
            <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-bullish-light">
              <svg className="h-7 w-7 text-bullish-dark" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h3 className="mt-4 text-lg font-semibold text-zinc-900 dark:text-zinc-100">Trade Executed</h3>
            <div className="mt-4 rounded-lg bg-zinc-50 p-4 text-sm dark:bg-zinc-700/50">
              <div className="flex justify-between py-1">
                <span className="text-zinc-500 dark:text-zinc-400">Action</span>
                <span className={`font-medium capitalize ${result.transaction.side === "buy" ? "text-bullish" : "text-bearish"}`}>
                  {result.transaction.side}
                </span>
              </div>
              <div className="flex justify-between py-1">
                <span className="text-zinc-500 dark:text-zinc-400">Ticker</span>
                <span className="font-medium text-zinc-900 dark:text-zinc-100">{result.transaction.ticker}</span>
              </div>
              <div className="flex justify-between py-1">
                <span className="text-zinc-500 dark:text-zinc-400">Quantity</span>
                <span className="font-medium text-zinc-900 dark:text-zinc-100">{result.transaction.quantity}</span>
              </div>
              <div className="flex justify-between py-1">
                <span className="text-zinc-500 dark:text-zinc-400">Price</span>
                <span className="font-medium text-zinc-900 dark:text-zinc-100">${parseFloat(result.transaction.price_per_share).toFixed(2)}</span>
              </div>
              <div className="flex justify-between border-t border-zinc-200 pt-2 mt-2 dark:border-zinc-600">
                <span className="font-medium text-zinc-700 dark:text-zinc-300">Total</span>
                <span className="font-bold text-zinc-900 dark:text-zinc-100">${parseFloat(result.transaction.total_amount).toFixed(2)}</span>
              </div>
            </div>
            <div className="mt-6 flex gap-3">
              <Link
                href="/portfolio"
                className="flex-1 rounded-lg bg-primary-600 px-4 py-2.5 text-center text-sm font-medium text-white transition-colors hover:bg-primary-700"
              >
                View Portfolio
              </Link>
              <button
                type="button"
                onClick={onClose}
                className="flex-1 rounded-lg border border-zinc-300 px-4 py-2.5 text-sm font-medium text-zinc-700 transition-colors hover:bg-zinc-50 dark:border-zinc-600 dark:bg-zinc-800 dark:text-zinc-200 dark:hover:bg-zinc-700"
              >
                Continue Analyzing
              </button>
            </div>
          </div>
        ) : (
          /* Trade Form */
          <div className="px-6 py-5">
            {portfolioLoading ? (
              <div className="space-y-4">
                <div className="h-10 animate-pulse rounded-lg bg-zinc-100 dark:bg-zinc-700" />
                <div className="h-10 animate-pulse rounded-lg bg-zinc-100 dark:bg-zinc-700" />
                <div className="h-10 animate-pulse rounded-lg bg-zinc-100 dark:bg-zinc-700" />
              </div>
            ) : portfolios.length === 0 ? (
              <div className="py-6 text-center">
                <p className="text-zinc-500 dark:text-zinc-400">No portfolio found.</p>
                <Link
                  href="/portfolio"
                  className="mt-3 inline-block text-sm font-medium text-primary-600 hover:underline"
                >
                  Create a portfolio first
                </Link>
              </div>
            ) : (
              <>
                {/* Buy/Sell Toggle */}
                <div className="flex rounded-lg bg-zinc-100 p-1 dark:bg-zinc-700">
                  <button
                    type="button"
                    onClick={() => { setSide("buy"); setError(null); }}
                    className={`flex-1 rounded-md py-2 text-sm font-semibold transition-colors ${
                      side === "buy"
                        ? "bg-bullish text-white shadow-sm"
                        : "text-zinc-600 hover:text-zinc-900 dark:text-zinc-300 dark:hover:text-zinc-100"
                    }`}
                  >
                    Buy
                  </button>
                  <button
                    type="button"
                    onClick={() => { setSide("sell"); setError(null); }}
                    className={`flex-1 rounded-md py-2 text-sm font-semibold transition-colors ${
                      side === "sell"
                        ? "bg-bearish text-white shadow-sm"
                        : "text-zinc-600 hover:text-zinc-900 dark:text-zinc-300 dark:hover:text-zinc-100"
                    }`}
                  >
                    Sell
                  </button>
                </div>

                {/* Price */}
                <div className="mt-5 flex items-baseline justify-between">
                  <span className="text-sm text-zinc-500 dark:text-zinc-400">Current Price</span>
                  <span className="text-xl font-bold text-zinc-900 dark:text-zinc-100">
                    {currentPrice != null ? `$${currentPrice.toFixed(2)}` : "—"}
                  </span>
                </div>

                {/* Portfolio Selector */}
                {portfolios.length > 1 && (
                  <div className="mt-4">
                    <label htmlFor="trade-portfolio" className="block text-sm font-medium text-zinc-600 dark:text-zinc-400">
                      Portfolio
                    </label>
                    <select
                      id="trade-portfolio"
                      value={selectedPortfolioId ?? ""}
                      onChange={(e) => setSelectedPortfolioId(e.target.value)}
                      className="mt-1 w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm dark:border-zinc-600 dark:bg-zinc-700 dark:text-zinc-100"
                    >
                      {portfolios.map((p) => (
                        <option key={p.id} value={p.id}>{p.name}</option>
                      ))}
                    </select>
                  </div>
                )}

                {/* Context Info */}
                <div className="mt-4 rounded-lg bg-zinc-50 px-4 py-2.5 text-sm dark:bg-zinc-700/50">
                  {side === "buy" ? (
                    <div className="flex justify-between">
                      <span className="text-zinc-500 dark:text-zinc-400">Cash Available</span>
                      <span className="font-medium text-zinc-900 dark:text-zinc-100">
                        ${cashAvailable.toLocaleString("en-US", { minimumFractionDigits: 2 })}
                      </span>
                    </div>
                  ) : (
                    <div className="flex justify-between">
                      <span className="text-zinc-500 dark:text-zinc-400">Shares Owned</span>
                      <span className="font-medium text-zinc-900 dark:text-zinc-100">{sharesQty}</span>
                    </div>
                  )}
                </div>

                {/* Quantity Input */}
                <div className="mt-4">
                  <label htmlFor="trade-quantity" className="block text-sm font-medium text-zinc-600 dark:text-zinc-400">
                    Shares
                  </label>
                  <input
                    id="trade-quantity"
                    type="number"
                    min={1}
                    max={10000}
                    step={1}
                    value={quantity}
                    onChange={(e) => { setQuantity(e.target.value); setError(null); }}
                    placeholder="Enter quantity"
                    className="mt-1 w-full rounded-lg border border-zinc-300 px-4 py-2.5 text-sm font-medium text-zinc-900 placeholder:text-zinc-400 focus:border-primary-500 focus:outline-none focus:ring-2 focus:ring-primary-500/20 dark:border-zinc-600 dark:bg-zinc-700 dark:text-zinc-100 dark:placeholder:text-zinc-500"
                    autoFocus
                  />
                </div>

                {/* Total Preview */}
                {totalCost != null && (
                  <div className="mt-4 flex items-baseline justify-between rounded-lg border border-zinc-200 bg-zinc-50 px-4 py-3 dark:border-zinc-600 dark:bg-zinc-700/50">
                    <span className="text-sm font-medium text-zinc-600 dark:text-zinc-400">
                      Estimated Total
                    </span>
                    <span className="text-lg font-bold text-zinc-900 dark:text-zinc-100">
                      ${totalCost.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                    </span>
                  </div>
                )}

                {/* Validation Error */}
                {validationError && (
                  <p className="mt-3 text-sm font-medium text-bearish">{validationError}</p>
                )}

                {/* Server Error */}
                {error && (
                  <p className="mt-3 text-sm font-medium text-bearish">{error}</p>
                )}

                {/* Submit */}
                <button
                  type="button"
                  onClick={handleSubmit}
                  disabled={!canSubmit || !!validationError}
                  className={`mt-5 w-full rounded-lg py-3 text-sm font-semibold text-white transition-colors disabled:cursor-not-allowed disabled:opacity-50 ${
                    side === "buy"
                      ? "bg-bullish hover:bg-bullish-dark"
                      : "bg-bearish hover:bg-bearish-dark"
                  }`}
                >
                  {submitting
                    ? "Executing..."
                    : `${side === "buy" ? "Buy" : "Sell"} ${validQty ? qty : ""} ${ticker}`}
                </button>
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

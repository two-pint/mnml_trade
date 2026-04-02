"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import type { PaperPortfolio } from "@repo/types";
import { paperTradingApi } from "@/lib/api";
import { PORTFOLIOS_CHANGED_EVENT } from "@/lib/portfolio-events";

function fmtCash(s: string | undefined): string {
  if (s == null) return "";
  const n = parseFloat(s);
  if (Number.isNaN(n)) return "";
  if (n >= 1_000_000) return `$${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1000) return `$${(n / 1000).toFixed(1)}k`;
  return `$${n.toFixed(0)}`;
}

type PortfolioNavSectionProps = {
  onNavigate?: () => void;
};

export function PortfolioNavSection({ onNavigate }: PortfolioNavSectionProps) {
  const pathname = usePathname();
  const [open, setOpen] = useState(() => pathname.startsWith("/portfolio"));
  const [portfolios, setPortfolios] = useState<PaperPortfolio[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(() => {
    setLoading(true);
    paperTradingApi
      .listPortfolios()
      .then((r) => setPortfolios(r.data))
      .catch(() => setPortfolios([]))
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    load();
  }, [load, pathname]);

  useEffect(() => {
    const onChange = () => load();
    window.addEventListener(PORTFOLIOS_CHANGED_EVENT, onChange);
    return () => window.removeEventListener(PORTFOLIOS_CHANGED_EVENT, onChange);
  }, [load]);

  useEffect(() => {
    if (pathname.startsWith("/portfolio")) setOpen(true);
  }, [pathname]);

  return (
    <div className="mt-1">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="flex w-full items-center justify-between gap-2 rounded-lg px-3 py-2 text-left text-sm font-medium text-zinc-700 transition-colors hover:bg-zinc-100 dark:text-zinc-300 dark:hover:bg-zinc-800"
        aria-expanded={open}
      >
        <span>Portfolios</span>
        <span className={`text-zinc-400 transition-transform ${open ? "rotate-180" : ""}`} aria-hidden>
          ▼
        </span>
      </button>
      {open && (
        <div className="mt-1 space-y-1 border-l border-zinc-200 pl-2 dark:border-zinc-700">
          {loading ? (
            <p className="px-2 py-1 text-xs text-zinc-400">Loading…</p>
          ) : portfolios.length === 0 ? (
            <Link
              href="/portfolio"
              onClick={onNavigate}
              className="block rounded-md px-2 py-1.5 text-sm text-zinc-600 hover:bg-zinc-100 dark:text-zinc-400 dark:hover:bg-zinc-800"
            >
              Create portfolio
            </Link>
          ) : (
            <>
              {portfolios.map((p) => {
                const base = `/portfolio/${p.id}`;
                const isOverview = pathname === base;
                const isTx = pathname === `${base}/transactions`;
                const cash = fmtCash(p.cash_balance);
                return (
                  <div key={p.id} className="space-y-0.5">
                    <Link
                      href={base}
                      onClick={onNavigate}
                      className={
                        isOverview
                          ? "block rounded-md bg-primary-50 px-2 py-1.5 text-sm font-medium text-primary-800 dark:bg-primary-950/40 dark:text-primary-200"
                          : "block rounded-md px-2 py-1.5 text-sm text-zinc-700 hover:bg-zinc-100 dark:text-zinc-300 dark:hover:bg-zinc-800"
                      }
                    >
                      <span className="line-clamp-2 break-words">{p.name}</span>
                      {cash ? (
                        <span className="mt-0.5 block text-xs font-normal text-zinc-500 dark:text-zinc-400">
                          {cash} cash
                        </span>
                      ) : null}
                    </Link>
                    <Link
                      href={`${base}/transactions`}
                      onClick={onNavigate}
                      className={
                        isTx
                          ? "block rounded-md py-1 pl-4 text-xs font-medium text-primary-700 dark:text-primary-300"
                          : "block rounded-md py-1 pl-4 text-xs text-zinc-500 hover:text-zinc-800 dark:text-zinc-400 dark:hover:text-zinc-100"
                      }
                    >
                      Transactions
                    </Link>
                  </div>
                );
              })}
              <Link
                href="/portfolio/new"
                onClick={onNavigate}
                className="mt-2 block rounded-md px-2 py-1.5 text-sm font-medium text-primary-600 hover:bg-primary-50 dark:text-primary-400 dark:hover:bg-primary-950/30"
              >
                + New portfolio
              </Link>
            </>
          )}
        </div>
      )}
    </div>
  );
}

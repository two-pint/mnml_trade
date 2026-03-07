"use client";

import { useEffect, useState } from "react";
import type { FundamentalAnalysis, IncomeStatement, BalanceSheet, CashFlow } from "@repo/types";
import { stocksApi } from "@/lib/api";

function fmt(n: number | null | undefined, opts?: { pct?: boolean; compact?: boolean; currency?: boolean }): string {
  if (n == null) return "—";
  if (opts?.pct) return `${(n * 100).toFixed(1)}%`;
  if (opts?.compact) {
    const abs = Math.abs(n);
    if (abs >= 1e12) return `${(n / 1e12).toFixed(1)}T`;
    if (abs >= 1e9) return `${(n / 1e9).toFixed(1)}B`;
    if (abs >= 1e6) return `${(n / 1e6).toFixed(1)}M`;
    if (abs >= 1e3) return `${(n / 1e3).toFixed(1)}K`;
    return n.toFixed(0);
  }
  if (opts?.currency) return `$${n.toFixed(2)}`;
  return typeof n === "number" ? n.toFixed(2) : String(n);
}

function ScoreBadge({ score, assessment }: { score: number; assessment: string }) {
  const bg =
    score >= 70 ? "bg-bullish-light text-bullish-dark" :
    score >= 40 ? "bg-primary-100 text-primary-800" :
    "bg-bearish-light text-bearish-dark";

  return (
    <div className="flex items-center gap-3">
      <div className="flex items-baseline gap-2">
        <span className="text-sm text-gray-500">Fundamental score</span>
        <span className="text-2xl font-bold text-gray-900">{score}</span>
      </div>
      <span className={`rounded-full px-3 py-1 text-sm font-medium ${bg}`}>
        {assessment}
      </span>
    </div>
  );
}

function MetricCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-gray-100 bg-gray-50/50 px-4 py-3">
      <dt className="text-xs text-gray-500">{label}</dt>
      <dd className="mt-1 text-lg font-semibold text-gray-900">{value}</dd>
    </div>
  );
}

function RatingBadge({ label, value }: { label: string; value: string }) {
  const color =
    value === "Strong" || value === "Healthy" ? "text-bullish" :
    value === "Weak" ? "text-bearish" : "text-gray-600";

  return (
    <div className="flex items-center gap-2 text-sm">
      <span className="text-gray-500">{label}:</span>
      <span className={`font-medium ${color}`}>{value}</span>
    </div>
  );
}

function StatementTable<T extends object>({
  title,
  data,
  columns,
}: {
  title: string;
  data: T[];
  columns: { key: keyof T; label: string; format?: "compact" | "currency" | "pct" }[];
}) {
  const [open, setOpen] = useState(false);
  if (!data.length) return null;

  return (
    <div className="rounded-lg border border-gray-100">
      <button
        type="button"
        onClick={() => setOpen(!open)}
        className="flex w-full items-center justify-between px-4 py-3 text-left text-sm font-semibold text-gray-700 hover:bg-gray-50"
      >
        {title}
        <span className="text-gray-400">{open ? "▲" : "▼"}</span>
      </button>
      {open && (
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="border-t border-gray-100 bg-gray-50">
                <th className="px-4 py-2 font-medium text-gray-500">Date</th>
                {columns.map((c) => (
                  <th key={String(c.key)} className="px-4 py-2 text-right font-medium text-gray-500">
                    {c.label}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {data.slice(0, 8).map((row, i) => {
                const r = row as Record<string, unknown>;
                return (
                  <tr key={i} className="border-t border-gray-50">
                    <td className="px-4 py-2 text-gray-600">{(r["date"] as string) ?? "—"}</td>
                    {columns.map((c) => (
                      <td key={String(c.key)} className="px-4 py-2 text-right text-gray-900">
                        {fmt(r[String(c.key)] as number | null, {
                          compact: c.format === "compact",
                          currency: c.format === "currency",
                          pct: c.format === "pct",
                        })}
                      </td>
                    ))}
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

export default function FundamentalTab({ ticker }: { ticker: string }) {
  const [data, setData] = useState<FundamentalAnalysis | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  useEffect(() => {
    if (!ticker) return;
    setLoading(true);
    setError(false);
    stocksApi
      .getStockFundamental(ticker)
      .then(setData)
      .catch(() => setError(true))
      .finally(() => setLoading(false));
  }, [ticker]);

  if (loading) {
    return (
      <section className="mt-6 space-y-4">
        <div className="h-20 animate-pulse rounded-xl bg-gray-100" />
        <div className="h-40 animate-pulse rounded-xl bg-gray-100" />
        <div className="h-40 animate-pulse rounded-xl bg-gray-100" />
      </section>
    );
  }

  if (error || !data) {
    return (
      <section className="mt-6 rounded-xl border border-gray-200 bg-white p-12 text-center shadow-sm">
        <p className="text-gray-500">Fundamental data unavailable</p>
      </section>
    );
  }

  const { profile, ratios } = data;

  return (
    <section className="mt-6 space-y-6">
      {/* Score & Ratings */}
      <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <ScoreBadge score={data.score} assessment={data.assessment} />
        <div className="mt-4 flex flex-wrap gap-6">
          <RatingBadge label="Growth" value={data.growth_rating} />
          <RatingBadge label="Financial Health" value={data.health_rating} />
        </div>
      </div>

      {/* Company Overview */}
      {profile && (
        <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
          <h3 className="mb-3 text-sm font-semibold text-gray-700">Company Overview</h3>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {profile.company_name && (
              <MetricCard label="Company" value={profile.company_name} />
            )}
            {profile.sector && (
              <MetricCard label="Sector" value={profile.sector} />
            )}
            {profile.industry && (
              <MetricCard label="Industry" value={profile.industry} />
            )}
            <MetricCard label="Market Cap" value={fmt(profile.market_cap, { compact: true })} />
            {profile.employees != null && (
              <MetricCard label="Employees" value={profile.employees.toLocaleString()} />
            )}
            {(profile.city || profile.state || profile.country) && (
              <MetricCard
                label="Headquarters"
                value={[profile.city, profile.state, profile.country].filter(Boolean).join(", ")}
              />
            )}
          </div>
          {profile.description && (
            <p className="mt-4 text-sm leading-relaxed text-gray-600 line-clamp-4">
              {profile.description}
            </p>
          )}
        </div>
      )}

      {/* Valuation */}
      <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h3 className="mb-4 text-sm font-semibold text-gray-700">Valuation</h3>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <MetricCard label="P/E Ratio" value={fmt(ratios.pe_ratio)} />
          <MetricCard label="P/B Ratio" value={fmt(ratios.pb_ratio)} />
          <MetricCard label="PEG Ratio" value={fmt(ratios.peg_ratio)} />
          <MetricCard label="P/S Ratio" value={fmt(ratios.ps_ratio)} />
        </div>
      </div>

      {/* Profitability */}
      <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h3 className="mb-4 text-sm font-semibold text-gray-700">Profitability</h3>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
          <MetricCard label="Gross Margin" value={fmt(ratios.gross_margin, { pct: true })} />
          <MetricCard label="Operating Margin" value={fmt(ratios.operating_margin, { pct: true })} />
          <MetricCard label="Net Margin" value={fmt(ratios.net_margin, { pct: true })} />
          <MetricCard label="ROE" value={fmt(ratios.roe, { pct: true })} />
          <MetricCard label="ROA" value={fmt(ratios.roa, { pct: true })} />
        </div>
      </div>

      {/* Financial Health */}
      <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h3 className="mb-4 text-sm font-semibold text-gray-700">Financial Health</h3>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <MetricCard label="Current Ratio" value={fmt(ratios.current_ratio)} />
          <MetricCard label="Quick Ratio" value={fmt(ratios.quick_ratio)} />
          <MetricCard label="Debt / Equity" value={fmt(ratios.debt_to_equity)} />
          <MetricCard label="Interest Coverage" value={fmt(ratios.interest_coverage)} />
        </div>
      </div>

      {/* Financial Statements */}
      <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h3 className="mb-4 text-sm font-semibold text-gray-700">Financial Statements</h3>
        <div className="space-y-2">
          <StatementTable<IncomeStatement>
            title="Income Statement"
            data={data.income_statement}
            columns={[
              { key: "revenue", label: "Revenue", format: "compact" },
              { key: "gross_profit", label: "Gross Profit", format: "compact" },
              { key: "operating_income", label: "Op. Income", format: "compact" },
              { key: "net_income", label: "Net Income", format: "compact" },
              { key: "eps_diluted", label: "EPS", format: "currency" },
            ]}
          />
          <StatementTable<BalanceSheet>
            title="Balance Sheet"
            data={data.balance_sheet}
            columns={[
              { key: "total_assets", label: "Total Assets", format: "compact" },
              { key: "total_liabilities", label: "Liabilities", format: "compact" },
              { key: "total_equity", label: "Equity", format: "compact" },
              { key: "cash_and_equivalents", label: "Cash", format: "compact" },
              { key: "total_debt", label: "Total Debt", format: "compact" },
            ]}
          />
          <StatementTable<CashFlow>
            title="Cash Flow Statement"
            data={data.cash_flow}
            columns={[
              { key: "operating_cash_flow", label: "Op. Cash Flow", format: "compact" },
              { key: "capital_expenditure", label: "CapEx", format: "compact" },
              { key: "free_cash_flow", label: "Free Cash Flow", format: "compact" },
              { key: "dividends_paid", label: "Dividends", format: "compact" },
            ]}
          />
        </div>
      </div>
    </section>
  );
}

import { useEffect, useState } from "react";
import { View, Text, ActivityIndicator, TouchableOpacity } from "react-native";
import type { FundamentalAnalysis } from "@repo/types";
import { stocksApi } from "@/lib/api";

function formatNum(n: number | null | undefined, decimals = 2): string {
  if (n == null) return "—";
  return n.toFixed(decimals);
}

function formatCompact(n: number | null | undefined): string {
  if (n == null) return "—";
  const abs = Math.abs(n);
  if (abs >= 1e12) return `$${(n / 1e12).toFixed(1)}T`;
  if (abs >= 1e9) return `$${(n / 1e9).toFixed(1)}B`;
  if (abs >= 1e6) return `$${(n / 1e6).toFixed(1)}M`;
  if (abs >= 1e3) return `$${(n / 1e3).toFixed(0)}K`;
  return `$${n.toLocaleString()}`;
}

function formatPct(n: number | null | undefined): string {
  if (n == null) return "—";
  return `${(n * 100).toFixed(1)}%`;
}

function MetricRow({ label, value }: { label: string; value: string }) {
  return (
    <View className="flex-row justify-between border-b border-gray-50 py-2">
      <Text className="text-sm text-gray-500">{label}</Text>
      <Text className="text-sm font-medium text-gray-900">{value}</Text>
    </View>
  );
}

function SectionCard({
  title,
  children,
  collapsible = false,
}: {
  title: string;
  children: React.ReactNode;
  collapsible?: boolean;
}) {
  const [open, setOpen] = useState(!collapsible);

  return (
    <View className="rounded-xl border border-gray-200 bg-white p-4">
      <TouchableOpacity
        onPress={collapsible ? () => setOpen(!open) : undefined}
        activeOpacity={collapsible ? 0.7 : 1}
        className="flex-row items-center justify-between"
      >
        <Text className="text-sm font-semibold text-gray-700">{title}</Text>
        {collapsible && (
          <Text className="text-xs text-gray-400">{open ? "▲" : "▼"}</Text>
        )}
      </TouchableOpacity>
      {open && <View className="mt-3">{children}</View>}
    </View>
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
      <View className="items-center py-12">
        <ActivityIndicator size="small" color="#4c6ef5" />
      </View>
    );
  }

  if (error || !data) {
    return (
      <View className="items-center py-12">
        <Text className="text-gray-500">Fundamental data unavailable</Text>
      </View>
    );
  }

  const assessmentColor =
    data.assessment === "Undervalued"
      ? "bg-green-100 text-green-800"
      : data.assessment === "Overvalued"
        ? "bg-red-100 text-red-800"
        : "bg-gray-100 text-gray-700";

  return (
    <View className="gap-4 p-4">
      {/* Score */}
      <View className="items-center rounded-xl border border-gray-200 bg-white p-4">
        <Text className="text-sm text-gray-500">Fundamental Score</Text>
        <Text className="mt-1 text-3xl font-bold text-gray-900">{data.score}</Text>
        <View className={`mt-2 rounded-full px-3 py-1 ${assessmentColor}`}>
          <Text className="text-sm font-medium">{data.assessment}</Text>
        </View>
        <View className="mt-2 flex-row gap-4">
          <Text className="text-xs text-gray-500">
            Growth: <Text className="font-medium text-gray-700">{data.growth_rating}</Text>
          </Text>
          <Text className="text-xs text-gray-500">
            Health: <Text className="font-medium text-gray-700">{data.health_rating}</Text>
          </Text>
        </View>
      </View>

      {/* Company Overview */}
      {data.profile && (
        <SectionCard title="Company Overview">
          {data.profile.description && (
            <Text className="mb-3 text-xs leading-5 text-gray-600" numberOfLines={4}>
              {data.profile.description}
            </Text>
          )}
          <MetricRow label="Sector" value={data.profile.sector ?? "—"} />
          <MetricRow label="Industry" value={data.profile.industry ?? "—"} />
          <MetricRow label="Market Cap" value={formatCompact(data.profile.market_cap)} />
          <MetricRow
            label="Employees"
            value={data.profile.employees?.toLocaleString() ?? "—"}
          />
        </SectionCard>
      )}

      {/* Valuation */}
      <SectionCard title="Valuation">
        <MetricRow label="P/E Ratio" value={formatNum(data.ratios.pe_ratio)} />
        <MetricRow label="P/B Ratio" value={formatNum(data.ratios.pb_ratio)} />
        <MetricRow label="PEG Ratio" value={formatNum(data.ratios.peg_ratio)} />
        <MetricRow label="P/S Ratio" value={formatNum(data.ratios.ps_ratio)} />
      </SectionCard>

      {/* Profitability */}
      <SectionCard title="Profitability">
        <MetricRow label="Gross Margin" value={formatPct(data.ratios.gross_margin)} />
        <MetricRow label="Operating Margin" value={formatPct(data.ratios.operating_margin)} />
        <MetricRow label="Net Margin" value={formatPct(data.ratios.net_margin)} />
        <MetricRow label="ROE" value={formatPct(data.ratios.roe)} />
        <MetricRow label="ROA" value={formatPct(data.ratios.roa)} />
      </SectionCard>

      {/* Financial Health */}
      <SectionCard title="Financial Health">
        <MetricRow label="Current Ratio" value={formatNum(data.ratios.current_ratio)} />
        <MetricRow label="Quick Ratio" value={formatNum(data.ratios.quick_ratio)} />
        <MetricRow label="Debt/Equity" value={formatNum(data.ratios.debt_to_equity)} />
        <MetricRow
          label="Interest Coverage"
          value={formatNum(data.ratios.interest_coverage)}
        />
      </SectionCard>

      {/* Income Statement */}
      {data.income_statement.length > 0 && (
        <SectionCard title="Income Statement (Recent)" collapsible>
          {data.income_statement.slice(0, 4).map((row, i) => (
            <View key={i} className="mb-3 rounded-lg bg-gray-50 p-3">
              <Text className="mb-1 text-xs font-medium text-gray-500">
                {row.date ?? "—"} ({row.period ?? "—"})
              </Text>
              <MetricRow label="Revenue" value={formatCompact(row.revenue)} />
              <MetricRow label="Net Income" value={formatCompact(row.net_income)} />
              <MetricRow label="EPS" value={formatNum(row.eps_diluted)} />
            </View>
          ))}
        </SectionCard>
      )}

      {/* Balance Sheet */}
      {data.balance_sheet.length > 0 && (
        <SectionCard title="Balance Sheet (Recent)" collapsible>
          {data.balance_sheet.slice(0, 4).map((row, i) => (
            <View key={i} className="mb-3 rounded-lg bg-gray-50 p-3">
              <Text className="mb-1 text-xs font-medium text-gray-500">
                {row.date ?? "—"} ({row.period ?? "—"})
              </Text>
              <MetricRow label="Total Assets" value={formatCompact(row.total_assets)} />
              <MetricRow label="Total Debt" value={formatCompact(row.total_debt)} />
              <MetricRow label="Cash" value={formatCompact(row.cash_and_equivalents)} />
            </View>
          ))}
        </SectionCard>
      )}

      {/* Cash Flow */}
      {data.cash_flow.length > 0 && (
        <SectionCard title="Cash Flow (Recent)" collapsible>
          {data.cash_flow.slice(0, 4).map((row, i) => (
            <View key={i} className="mb-3 rounded-lg bg-gray-50 p-3">
              <Text className="mb-1 text-xs font-medium text-gray-500">
                {row.date ?? "—"} ({row.period ?? "—"})
              </Text>
              <MetricRow label="Operating" value={formatCompact(row.operating_cash_flow)} />
              <MetricRow label="Free Cash Flow" value={formatCompact(row.free_cash_flow)} />
            </View>
          ))}
        </SectionCard>
      )}
    </View>
  );
}

export interface AgentAnalysis {
  summary: string;
  consideration?: string;
  technical_summary?: string;
  institutional_summary?: string;
  bull_points?: string[];
  bear_points?: string[];
  cached_at?: string;
}

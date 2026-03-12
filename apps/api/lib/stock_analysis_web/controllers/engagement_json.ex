defmodule StockAnalysisWeb.EngagementJSON do
  alias StockAnalysis.Engagement.WatchlistItem
  alias StockAnalysis.Engagement.HistoryEntry

  def watchlist(%{items: items}) do
    %{data: Enum.map(items, &watchlist_item_map/1)}
  end

  def watchlist_item(%{item: item}) do
    %{data: watchlist_item_map(item)}
  end

  defp watchlist_item_map(%WatchlistItem{} = w) do
    %{
      id: w.id,
      ticker: w.ticker,
      added_at: w.added_at,
      inserted_at: w.inserted_at
    }
  end

  def history(%{entries: entries}) do
    %{data: Enum.map(entries, &history_entry_map/1)}
  end

  defp history_entry_map(%HistoryEntry{} = h) do
    %{
      id: h.id,
      ticker: h.ticker,
      viewed_at: h.viewed_at
    }
  end
end

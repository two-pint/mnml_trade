defmodule StockAnalysis.Engagement do
  @moduledoc """
  Context for user engagement features: watchlists and analysis history.
  """

  import Ecto.Query
  alias StockAnalysis.Repo
  alias StockAnalysis.Engagement.WatchlistItem
  alias StockAnalysis.Engagement.HistoryEntry

  @max_history 20

  # --- Watchlist ---

  def add_to_watchlist(user_id, %{"ticker" => ticker}) do
    add_to_watchlist(user_id, ticker)
  end

  def add_to_watchlist(user_id, ticker) when is_binary(ticker) do
    ticker = ticker |> String.trim() |> String.upcase()

    if ticker == "" do
      {:error, :invalid_ticker}
    else
      case Repo.get_by(WatchlistItem, user_id: user_id, ticker: ticker) do
        %WatchlistItem{} = existing ->
          {:ok, existing}

        nil ->
          %WatchlistItem{}
          |> WatchlistItem.changeset(%{ticker: ticker}, user_id)
          |> Repo.insert()
      end
    end
  end

  def add_to_watchlist(_user_id, _), do: {:error, :invalid_ticker}

  def remove_from_watchlist(user_id, ticker) when is_binary(ticker) do
    ticker = ticker |> String.trim() |> String.upcase()

    case Repo.get_by(WatchlistItem, user_id: user_id, ticker: ticker) do
      %WatchlistItem{} = item ->
        Repo.delete(item)
        {:ok, :removed}

      nil ->
        {:error, :not_found}
    end
  end

  def list_watchlist(user_id) do
    WatchlistItem
    |> where([w], w.user_id == ^user_id)
    |> order_by([w], desc: w.added_at)
    |> Repo.all()
  end

  # --- Analysis History ---

  def record_view(user_id, ticker) when is_binary(ticker) do
    ticker = ticker |> String.trim() |> String.upcase()

    if ticker == "" do
      :ok
    else
      %HistoryEntry{}
      |> HistoryEntry.changeset(%{ticker: ticker}, user_id)
      |> Repo.insert()

      prune_history(user_id)
      :ok
    end
  end

  def record_view(_user_id, _ticker), do: :ok

  def list_history(user_id, limit \\ @max_history) do
    HistoryEntry
    |> where([h], h.user_id == ^user_id)
    |> order_by([h], desc: h.viewed_at)
    |> limit(^limit)
    |> Repo.all()
  end

  defp prune_history(user_id) do
    keep_ids =
      HistoryEntry
      |> where([h], h.user_id == ^user_id)
      |> order_by([h], desc: h.viewed_at)
      |> limit(@max_history)
      |> select([h], h.id)
      |> Repo.all()

    HistoryEntry
    |> where([h], h.user_id == ^user_id and h.id not in ^keep_ids)
    |> Repo.delete_all()
  end
end

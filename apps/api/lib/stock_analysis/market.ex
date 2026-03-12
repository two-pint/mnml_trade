defmodule StockAnalysis.Market do
  @moduledoc """
  Context for historical market data: tickers, price snapshots, and score snapshots.

  Workers and controllers call this module instead of Repo directly. Provides
  upsert/insert operations for background jobs and query functions for the
  history API endpoints.
  """
  import Ecto.Query

  alias StockAnalysis.Repo
  alias StockAnalysis.Market.{Ticker, PriceSnapshot, ScoreSnapshot}

  @doc """
  Inserts or updates a ticker by symbol. Returns `{:ok, ticker}` or `{:error, changeset}`.
  """
  def upsert_ticker(attrs) do
    changeset = Ticker.changeset(%Ticker{}, attrs)

    Repo.insert(changeset,
      on_conflict: {:replace, [:name, :sector, :market_cap, :is_active, :updated_at]},
      conflict_target: :symbol,
      returning: true
    )
  end

  @doc """
  Finds a ticker by symbol. Returns `{:ok, ticker}` or `{:error, :not_found}`.
  """
  def get_ticker(symbol) when is_binary(symbol) do
    symbol = String.upcase(String.trim(symbol))

    case Repo.get_by(Ticker, symbol: symbol) do
      nil -> {:error, :not_found}
      ticker -> {:ok, ticker}
    end
  end

  @doc """
  Returns all tickers where `is_active == true`.
  """
  def list_active_tickers do
    Ticker
    |> where([t], t.is_active == true)
    |> Repo.all()
  end

  @doc """
  Bulk inserts price snapshots for a ticker. Skips duplicates (`on_conflict: :nothing`).

  `list_of_attrs` is a list of maps with keys: `date`, `open`, `high`, `low`, `close`, `volume`.
  Returns `:ok`.
  """
  def insert_price_snapshots(_ticker_id, []), do: :ok

  def insert_price_snapshots(ticker_id, list_of_attrs) when is_list(list_of_attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      Enum.map(list_of_attrs, fn attrs ->
        attrs
        |> Map.put(:ticker_id, ticker_id)
        |> Map.put(:inserted_at, now)
        |> Map.put(:updated_at, now)
      end)

    Repo.insert_all(PriceSnapshot, entries,
      on_conflict: :nothing,
      conflict_target: [:ticker_id, :date]
    )

    :ok
  end

  @doc """
  Inserts or updates a score snapshot for a given ticker and date.

  `scores_map` is a map with any subset of:
  `technical_score`, `fundamental_score`, `sentiment_score`, `smart_money_score`,
  `recommendation_score`, `recommendation_label`, `confidence`.

  Returns `{:ok, snapshot}` or `{:error, changeset}`.
  """
  def insert_score_snapshot(ticker_id, date, scores_map) when is_map(scores_map) do
    attrs = Map.merge(scores_map, %{ticker_id: ticker_id, date: date})
    changeset = ScoreSnapshot.changeset(%ScoreSnapshot{}, attrs)

    replace_fields =
      scores_map
      |> Map.keys()
      |> Enum.map(fn
        k when is_atom(k) -> k
        k when is_binary(k) -> String.to_existing_atom(k)
      end)

    Repo.insert(changeset,
      on_conflict: {:replace, replace_fields ++ [:updated_at]},
      conflict_target: [:ticker_id, :date],
      returning: true
    )
  end

  @doc """
  Returns the last `days` price snapshots for a ticker, ordered by date descending.

  Returns `{:ok, [PriceSnapshot.t()]}` or `{:error, :not_found}` if the ticker doesn't exist.
  """
  def get_price_history(symbol, days \\ 30) when is_binary(symbol) do
    case get_ticker(symbol) do
      {:ok, ticker} ->
        cutoff = Date.add(Date.utc_today(), -days)

        history =
          PriceSnapshot
          |> where([p], p.ticker_id == ^ticker.id and p.date >= ^cutoff)
          |> order_by([p], desc: p.date)
          |> limit(^days)
          |> Repo.all()

        {:ok, history}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Returns the last `days` score snapshots for a ticker, ordered by date descending.

  Returns `{:ok, [ScoreSnapshot.t()]}` or `{:error, :not_found}` if the ticker doesn't exist.
  """
  def get_score_history(symbol, days \\ 30) when is_binary(symbol) do
    case get_ticker(symbol) do
      {:ok, ticker} ->
        cutoff = Date.add(Date.utc_today(), -days)

        history =
          ScoreSnapshot
          |> where([s], s.ticker_id == ^ticker.id and s.date >= ^cutoff)
          |> order_by([s], desc: s.date)
          |> limit(^days)
          |> Repo.all()

        {:ok, history}

      {:error, _} = err ->
        err
    end
  end
end

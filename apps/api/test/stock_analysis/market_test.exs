defmodule StockAnalysis.MarketTest do
  use StockAnalysis.DataCase, async: true

  alias StockAnalysis.Market
  alias StockAnalysis.Market.{Ticker, PriceSnapshot, ScoreSnapshot}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp insert_ticker(attrs \\ %{}) do
    defaults = %{symbol: "AAPL", name: "Apple Inc.", sector: "Technology"}
    {:ok, ticker} = Market.upsert_ticker(Map.merge(defaults, attrs))
    ticker
  end

  defp price_attrs(date, opts \\ []) do
    %{
      date: date,
      open: Keyword.get(opts, :open, 150.00),
      high: Keyword.get(opts, :high, 155.00),
      low: Keyword.get(opts, :low, 148.00),
      close: Keyword.get(opts, :close, 152.00),
      volume: Keyword.get(opts, :volume, 50_000_000)
    }
  end

  # ---------------------------------------------------------------------------
  # upsert_ticker/1
  # ---------------------------------------------------------------------------

  describe "upsert_ticker/1" do
    test "inserts a new ticker" do
      assert {:ok, ticker} = Market.upsert_ticker(%{symbol: "MSFT", name: "Microsoft"})
      assert ticker.symbol == "MSFT"
      assert ticker.name == "Microsoft"
      assert ticker.is_active == true
    end

    test "upcases the symbol" do
      assert {:ok, ticker} = Market.upsert_ticker(%{symbol: "aapl", name: "Apple"})
      assert ticker.symbol == "AAPL"
    end

    test "updates existing ticker on re-upsert (idempotent)" do
      {:ok, _} = Market.upsert_ticker(%{symbol: "AAPL", name: "Apple Inc.", sector: "Tech"})
      {:ok, updated} = Market.upsert_ticker(%{symbol: "AAPL", name: "Apple Inc. (Updated)", sector: "Technology"})
      assert updated.symbol == "AAPL"
      assert updated.name == "Apple Inc. (Updated)"
      assert updated.sector == "Technology"
      assert Repo.aggregate(Ticker, :count, :id) == 1
    end

    test "returns error for missing required fields" do
      assert {:error, changeset} = Market.upsert_ticker(%{symbol: "AAPL"})
      assert "can't be blank" in errors_on(changeset).name
    end
  end

  # ---------------------------------------------------------------------------
  # get_ticker/1
  # ---------------------------------------------------------------------------

  describe "get_ticker/1" do
    test "returns {:ok, ticker} for existing symbol" do
      insert_ticker()
      assert {:ok, ticker} = Market.get_ticker("AAPL")
      assert ticker.symbol == "AAPL"
    end

    test "is case-insensitive" do
      insert_ticker()
      assert {:ok, ticker} = Market.get_ticker("aapl")
      assert ticker.symbol == "AAPL"
    end

    test "returns {:error, :not_found} for unknown symbol" do
      assert {:error, :not_found} = Market.get_ticker("UNKNOWN")
    end
  end

  # ---------------------------------------------------------------------------
  # list_active_tickers/0
  # ---------------------------------------------------------------------------

  describe "list_active_tickers/0" do
    test "returns only active tickers" do
      insert_ticker(%{symbol: "AAPL", name: "Apple"})
      insert_ticker(%{symbol: "MSFT", name: "Microsoft"})
      {:ok, inactive} = Market.upsert_ticker(%{symbol: "IBM", name: "IBM", is_active: false})
      refute inactive.is_active

      active = Market.list_active_tickers()
      symbols = Enum.map(active, & &1.symbol)
      assert "AAPL" in symbols
      assert "MSFT" in symbols
      refute "IBM" in symbols
    end

    test "returns empty list when no active tickers" do
      assert Market.list_active_tickers() == []
    end
  end

  # ---------------------------------------------------------------------------
  # insert_price_snapshots/2
  # ---------------------------------------------------------------------------

  describe "insert_price_snapshots/2" do
    test "inserts multiple snapshots" do
      ticker = insert_ticker()
      today = Date.utc_today()
      yesterday = Date.add(today, -1)

      :ok = Market.insert_price_snapshots(ticker.id, [
        price_attrs(today),
        price_attrs(yesterday)
      ])

      assert Repo.aggregate(PriceSnapshot, :count, :id) == 2
    end

    test "skips duplicates (on_conflict: :nothing)" do
      ticker = insert_ticker()
      today = Date.utc_today()
      attrs = [price_attrs(today)]

      :ok = Market.insert_price_snapshots(ticker.id, attrs)
      :ok = Market.insert_price_snapshots(ticker.id, attrs)

      assert Repo.aggregate(PriceSnapshot, :count, :id) == 1
    end

    test "accepts empty list without error" do
      ticker = insert_ticker()
      assert :ok = Market.insert_price_snapshots(ticker.id, [])
    end
  end

  # ---------------------------------------------------------------------------
  # insert_score_snapshot/3
  # ---------------------------------------------------------------------------

  describe "insert_score_snapshot/3" do
    test "inserts a score snapshot" do
      ticker = insert_ticker()
      date = Date.utc_today()

      assert {:ok, snapshot} = Market.insert_score_snapshot(ticker.id, date, %{
        technical_score: 75.0,
        fundamental_score: 60.0,
        recommendation_score: 68.0,
        recommendation_label: "Buy",
        confidence: 80.0
      })

      assert snapshot.technical_score == 75.0
      assert snapshot.recommendation_label == "Buy"
    end

    test "updates existing snapshot on re-insert (upsert)" do
      ticker = insert_ticker()
      date = Date.utc_today()

      {:ok, _} = Market.insert_score_snapshot(ticker.id, date, %{
        technical_score: 75.0,
        recommendation_label: "Buy"
      })

      {:ok, updated} = Market.insert_score_snapshot(ticker.id, date, %{
        technical_score: 80.0,
        recommendation_label: "Strong Buy"
      })

      assert updated.technical_score == 80.0
      assert updated.recommendation_label == "Strong Buy"
      assert Repo.aggregate(ScoreSnapshot, :count, :id) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # get_price_history/2
  # ---------------------------------------------------------------------------

  describe "get_price_history/2" do
    test "returns price history for a ticker" do
      ticker = insert_ticker()
      today = Date.utc_today()

      :ok = Market.insert_price_snapshots(ticker.id, [
        price_attrs(today),
        price_attrs(Date.add(today, -1)),
        price_attrs(Date.add(today, -2))
      ])

      assert {:ok, history} = Market.get_price_history("AAPL")
      assert length(history) == 3
    end

    test "respects the days limit" do
      ticker = insert_ticker()
      today = Date.utc_today()

      entries = Enum.map(0..59, fn i -> price_attrs(Date.add(today, -i)) end)
      :ok = Market.insert_price_snapshots(ticker.id, entries)

      assert {:ok, history} = Market.get_price_history("AAPL", 30)
      assert length(history) == 30
    end

    test "returns results ordered by date descending" do
      ticker = insert_ticker()
      today = Date.utc_today()

      :ok = Market.insert_price_snapshots(ticker.id, [
        price_attrs(today),
        price_attrs(Date.add(today, -1)),
        price_attrs(Date.add(today, -2))
      ])

      {:ok, [first | _]} = Market.get_price_history("AAPL")
      assert first.date == today
    end

    test "returns {:error, :not_found} for unknown ticker" do
      assert {:error, :not_found} = Market.get_price_history("UNKNOWN")
    end
  end

  # ---------------------------------------------------------------------------
  # get_score_history/2
  # ---------------------------------------------------------------------------

  describe "get_score_history/2" do
    test "returns score history for a ticker" do
      ticker = insert_ticker()
      today = Date.utc_today()

      {:ok, _} = Market.insert_score_snapshot(ticker.id, today, %{
        technical_score: 70.0,
        recommendation_label: "Buy"
      })

      {:ok, _} = Market.insert_score_snapshot(ticker.id, Date.add(today, -1), %{
        technical_score: 65.0,
        recommendation_label: "Hold"
      })

      assert {:ok, history} = Market.get_score_history("AAPL")
      assert length(history) == 2
    end

    test "respects the days limit" do
      ticker = insert_ticker()
      today = Date.utc_today()

      Enum.each(0..59, fn i ->
        Market.insert_score_snapshot(ticker.id, Date.add(today, -i), %{
          technical_score: 50.0
        })
      end)

      assert {:ok, history} = Market.get_score_history("AAPL", 30)
      assert length(history) == 30
    end

    test "returns {:error, :not_found} for unknown ticker" do
      assert {:error, :not_found} = Market.get_score_history("UNKNOWN")
    end
  end
end

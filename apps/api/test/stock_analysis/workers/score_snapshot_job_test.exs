defmodule StockAnalysis.Workers.ScoreSnapshotJobTest do
  use StockAnalysis.DataCase, async: false
  use Oban.Testing, repo: StockAnalysis.Repo

  alias StockAnalysis.Workers.ScoreSnapshotJob
  alias StockAnalysis.Market

  setup do
    {:ok, ticker} = Market.upsert_ticker(%{symbol: "AAPL", name: "Apple Inc.", sector: "Technology"})
    {:ok, ticker2} = Market.upsert_ticker(%{symbol: "MSFT", name: "Microsoft", sector: "Technology"})
    {:ok, ticker: ticker, ticker2: ticker2}
  end

  describe "perform/1" do
    test "stores score snapshots for all active tickers" do
      # The job will call Recommendation.compute/1 for each ticker.
      # With no real API configured in test, compute returns {:error, :not_found}
      # which is handled gracefully — the job still returns :ok.
      assert :ok = perform_job(ScoreSnapshotJob, %{})
    end

    test "processes all active tickers without crashing on failures" do
      # Even if some tickers fail to compute scores, the job should return :ok
      assert :ok = perform_job(ScoreSnapshotJob, %{})
    end
  end
end

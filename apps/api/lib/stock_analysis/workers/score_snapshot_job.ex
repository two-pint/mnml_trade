defmodule StockAnalysis.Workers.ScoreSnapshotJob do
  @moduledoc """
  Oban worker that computes analysis scores for all active tickers and stores
  one `score_snapshot` row per ticker per day.

  Scheduled daily at 22:00 UTC, one hour after `PriceSnapshotJob` so fresh
  price data is available before scores are computed.

  Uses `Recommendation.compute/1` which fetches all sub-scores (technical,
  fundamental, sentiment, institutional). One failing ticker does not stop
  the rest — errors are logged and the job returns `:ok`.
  """
  use Oban.Worker,
    queue: :sync,
    max_attempts: 3,
    unique: [period: 3600]

  require Logger

  alias StockAnalysis.Market
  alias StockAnalysis.Recommendation

  @impl Oban.Worker
  def perform(_job) do
    tickers = Market.list_active_tickers()
    date = Date.utc_today()
    Logger.info("[ScoreSnapshotJob] computing scores for #{length(tickers)} tickers on #{date}")

    Enum.each(tickers, &compute_and_store(&1, date))
    :ok
  end

  defp compute_and_store(ticker, date) do
    case Recommendation.compute(ticker.symbol) do
      {:ok, rec} ->
        scores = %{
          technical_score: rec.components[:technical],
          fundamental_score: rec.components[:fundamental],
          sentiment_score: rec.components[:sentiment],
          smart_money_score: rec.components[:institutional],
          recommendation_score: rec.recommendation_score,
          recommendation_label: rec.recommendation,
          confidence: rec.confidence
        }

        case Market.insert_score_snapshot(ticker.id, date, scores) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.warning("[ScoreSnapshotJob] DB insert failed for #{ticker.symbol}: #{inspect(reason)}")
        end

      {:error, reason} ->
        Logger.warning("[ScoreSnapshotJob] score computation failed for #{ticker.symbol}: #{inspect(reason)}")
    end
  end
end

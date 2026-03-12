defmodule Mix.Tasks.Mnml.SeedTickers do
  @shortdoc "Fetches S&P 500 constituents from FMP and upserts them into the tickers table"

  @moduledoc """
  Fetches the current S&P 500 constituent list from Financial Modeling Prep (FMP)
  and upserts each symbol into the `tickers` table.

  ## Usage

      mix mnml.seed_tickers

  ## When to run

  Run once after initial setup, or any time you want to refresh the tracked
  ticker universe (e.g. after an index reconstitution). The weekly Oban cron
  job (`SeedTickersJob`) automates this in production, but this task lets you
  trigger it manually.

  ## Expected runtime

  < 5 seconds (single FMP API call returning ~500 records).

  ## Idempotency

  Safe to re-run. Existing tickers are updated; no duplicates are created.
  """

  use Mix.Task

  require Logger

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    Logger.info("[seed_tickers] starting")

    case StockAnalysis.Workers.SeedTickersJob.perform(%Oban.Job{args: %{}}) do
      :ok ->
        count = StockAnalysis.Repo.aggregate(StockAnalysis.Market.Ticker, :count, :id)
        Mix.shell().info("Done. #{count} active tickers in database.")

      {:error, reason} ->
        Mix.raise("seed_tickers failed: #{inspect(reason)}")
    end
  end
end

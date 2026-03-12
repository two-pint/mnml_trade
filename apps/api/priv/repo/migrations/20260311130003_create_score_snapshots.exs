defmodule StockAnalysis.Repo.Migrations.CreateScoreSnapshots do
  use Ecto.Migration

  def change do
    create table(:score_snapshots) do
      add :ticker_id, references(:tickers, on_delete: :delete_all), null: false
      add :date, :date, null: false
      add :technical_score, :float
      add :fundamental_score, :float
      add :sentiment_score, :float
      add :smart_money_score, :float
      add :recommendation_score, :float
      add :recommendation_label, :string
      add :confidence, :float

      timestamps(type: :utc_datetime)
    end

    create unique_index(:score_snapshots, [:ticker_id, :date])
    create index(:score_snapshots, [:ticker_id])
  end
end

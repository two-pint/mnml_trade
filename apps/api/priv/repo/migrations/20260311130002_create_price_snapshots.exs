defmodule StockAnalysis.Repo.Migrations.CreatePriceSnapshots do
  use Ecto.Migration

  def change do
    create table(:price_snapshots) do
      add :ticker_id, references(:tickers, on_delete: :delete_all), null: false
      add :date, :date, null: false
      add :open, :decimal, null: false
      add :high, :decimal, null: false
      add :low, :decimal, null: false
      add :close, :decimal, null: false
      add :volume, :bigint, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:price_snapshots, [:ticker_id, :date])
    create index(:price_snapshots, [:ticker_id])
  end
end

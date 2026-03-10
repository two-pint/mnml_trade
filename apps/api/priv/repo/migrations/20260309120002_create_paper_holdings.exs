defmodule StockAnalysis.Repo.Migrations.CreatePaperHoldings do
  use Ecto.Migration

  def change do
    create table(:paper_holdings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :portfolio_id, references(:paper_portfolios, type: :binary_id, on_delete: :delete_all),
        null: false
      add :ticker, :string, null: false
      add :quantity, :decimal, null: false
      add :average_cost, :decimal, null: false
      add :total_cost, :decimal, null: false
      add :last_updated, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:paper_holdings, [:portfolio_id, :ticker])
  end
end

defmodule StockAnalysis.Repo.Migrations.CreatePaperTransactions do
  use Ecto.Migration

  def change do
    create table(:paper_transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :portfolio_id, references(:paper_portfolios, type: :binary_id, on_delete: :delete_all),
        null: false
      add :ticker, :string, null: false
      add :transaction_type, :string, null: false
      add :quantity, :decimal, null: false
      add :price_per_share, :decimal, null: false
      add :total_amount, :decimal, null: false
      add :recommendation_at_time, :string
      add :notes, :text
      add :executed_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:paper_transactions, [:portfolio_id, :executed_at],
      comment: "Ordered by most recent execution"
    )

    create index(:paper_transactions, [:portfolio_id, :ticker])
  end
end

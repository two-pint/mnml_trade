defmodule StockAnalysis.Repo.Migrations.CreatePaperPortfolios do
  use Ecto.Migration

  def change do
    create table(:paper_portfolios, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :nothing), null: false
      add :name, :string, null: false
      add :description, :text
      add :starting_balance, :decimal, default: 100_000, null: false
      add :cash_balance, :decimal, null: false
      add :is_active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:paper_portfolios, [:user_id])
  end
end

defmodule StockAnalysis.Repo.Migrations.CreateTickers do
  use Ecto.Migration

  def change do
    create table(:tickers) do
      add :symbol, :string, null: false
      add :name, :string, null: false
      add :sector, :string
      add :market_cap, :bigint
      add :is_active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tickers, [:symbol])
  end
end

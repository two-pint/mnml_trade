defmodule StockAnalysis.Repo.Migrations.CreateWatchlists do
  use Ecto.Migration

  def change do
    create table(:watchlists, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :ticker, :string, null: false
      add :added_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:watchlists, [:user_id, :ticker])
    create index(:watchlists, [:user_id])
  end
end

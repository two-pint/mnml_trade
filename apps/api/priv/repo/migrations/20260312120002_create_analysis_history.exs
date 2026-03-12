defmodule StockAnalysis.Repo.Migrations.CreateAnalysisHistory do
  use Ecto.Migration

  def change do
    create table(:analysis_history, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :ticker, :string, null: false
      add :viewed_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:analysis_history, [:user_id, :viewed_at])
  end
end

defmodule StockAnalysis.Repo.Migrations.CreateUserLlmSettings do
  use Ecto.Migration

  def change do
    create table(:user_llm_settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :encrypted_api_key, :binary, null: false
      add :model, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_llm_settings, [:user_id])
  end
end

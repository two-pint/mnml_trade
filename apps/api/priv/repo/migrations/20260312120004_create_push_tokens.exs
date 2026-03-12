defmodule StockAnalysis.Repo.Migrations.CreatePushTokens do
  use Ecto.Migration

  def change do
    create table(:push_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :string, null: false
      add :platform, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:push_tokens, [:token])
    create index(:push_tokens, [:user_id])

    alter table(:users) do
      add :notification_preferences, :map, default: %{
        "push_enabled" => true,
        "price_alerts" => true,
        "whale_alerts" => true
      }
    end
  end
end

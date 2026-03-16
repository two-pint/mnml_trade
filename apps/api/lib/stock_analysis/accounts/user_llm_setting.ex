defmodule StockAnalysis.Accounts.UserLlmSetting do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_llm_settings" do
    field :provider, :string
    field :encrypted_api_key, :binary
    field :model, :string
    field :user_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:provider, :encrypted_api_key, :model, :user_id])
    |> validate_required([:provider, :encrypted_api_key, :user_id])
    |> validate_inclusion(:provider, ["openai", "anthropic"])
    |> validate_length(:model, max: 128)
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:user_id)
  end
end

defmodule StockAnalysis.Notifications.PushToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "push_tokens" do
    field :token, :string
    field :platform, :string
    field :user_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  def changeset(push_token, attrs) do
    push_token
    |> cast(attrs, [:token, :platform, :user_id])
    |> validate_required([:token, :platform, :user_id])
    |> validate_inclusion(:platform, ["ios", "android", "web"])
    |> unique_constraint(:token)
    |> foreign_key_constraint(:user_id)
  end
end

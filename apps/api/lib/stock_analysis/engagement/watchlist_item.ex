defmodule StockAnalysis.Engagement.WatchlistItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "watchlists" do
    field :ticker, :string
    field :added_at, :utc_datetime_usec
    field :user_id, :binary_id

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(item, attrs, user_id) do
    item
    |> cast(attrs, [:ticker])
    |> validate_required([:ticker])
    |> put_change(:user_id, user_id)
    |> put_change(:added_at, DateTime.utc_now())
    |> update_change(:ticker, &String.upcase(String.trim(&1)))
    |> unique_constraint([:user_id, :ticker], name: :watchlists_user_id_ticker_index)
    |> foreign_key_constraint(:user_id)
  end
end

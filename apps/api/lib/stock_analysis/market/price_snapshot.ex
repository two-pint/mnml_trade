defmodule StockAnalysis.Market.PriceSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  schema "price_snapshots" do
    field :date, :date
    field :open, :decimal
    field :high, :decimal
    field :low, :decimal
    field :close, :decimal
    field :volume, :integer

    belongs_to :ticker, StockAnalysis.Market.Ticker

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(ticker_id date open high low close volume)a

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_number(:open, greater_than: 0)
    |> validate_number(:high, greater_than: 0)
    |> validate_number(:low, greater_than: 0)
    |> validate_number(:close, greater_than: 0)
    |> validate_number(:volume, greater_than_or_equal_to: 0)
    |> unique_constraint([:ticker_id, :date])
  end
end

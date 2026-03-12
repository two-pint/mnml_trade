defmodule StockAnalysis.Market.Ticker do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tickers" do
    field :symbol, :string
    field :name, :string
    field :sector, :string
    field :market_cap, :integer
    field :is_active, :boolean, default: true

    has_many :price_snapshots, StockAnalysis.Market.PriceSnapshot
    has_many :score_snapshots, StockAnalysis.Market.ScoreSnapshot

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(symbol name)a
  @optional_fields ~w(sector market_cap is_active)a

  def changeset(ticker, attrs) do
    ticker
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:symbol, min: 1, max: 10)
    |> update_change(:symbol, &String.upcase/1)
    |> unique_constraint(:symbol)
  end
end

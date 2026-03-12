defmodule StockAnalysis.Market.ScoreSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  schema "score_snapshots" do
    field :date, :date
    field :technical_score, :float
    field :fundamental_score, :float
    field :sentiment_score, :float
    field :smart_money_score, :float
    field :recommendation_score, :float
    field :recommendation_label, :string
    field :confidence, :float

    belongs_to :ticker, StockAnalysis.Market.Ticker

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(ticker_id date)a
  @optional_fields ~w(technical_score fundamental_score sentiment_score smart_money_score recommendation_score recommendation_label confidence)a

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:ticker_id, :date])
  end
end

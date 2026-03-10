defmodule StockAnalysis.PaperTrading.Holding do
  use Ecto.Schema
  import Ecto.Changeset

  alias StockAnalysis.PaperTrading.Portfolio

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "paper_holdings" do
    field :ticker, :string
    field :quantity, :decimal
    field :average_cost, :decimal
    field :total_cost, :decimal
    field :last_updated, :utc_datetime

    belongs_to :portfolio, Portfolio

    timestamps(type: :utc_datetime)
  end

  def changeset(holding, attrs) do
    holding
    |> cast(attrs, [:ticker, :quantity, :average_cost, :total_cost, :last_updated, :portfolio_id])
    |> validate_required([:ticker, :quantity, :average_cost, :total_cost, :portfolio_id])
    |> foreign_key_constraint(:portfolio_id)
    |> unique_constraint([:portfolio_id, :ticker],
      name: :paper_holdings_portfolio_id_ticker_index
    )
    |> update_change(:ticker, &String.upcase/1)
  end
end

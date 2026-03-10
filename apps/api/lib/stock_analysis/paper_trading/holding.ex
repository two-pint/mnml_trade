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

  def create_changeset(holding, attrs, portfolio_id) do
    holding
    |> cast(attrs, [:ticker, :quantity, :average_cost, :total_cost, :last_updated])
    |> validate_required([:ticker, :quantity, :average_cost, :total_cost])
    |> put_change(:portfolio_id, portfolio_id)
    |> foreign_key_constraint(:portfolio_id)
    |> unique_constraint([:portfolio_id, :ticker],
      name: :paper_holdings_portfolio_id_ticker_index
    )
    |> update_change(:ticker, &String.upcase/1)
  end

  def update_changeset(holding, attrs) do
    holding
    |> cast(attrs, [:quantity, :average_cost, :total_cost, :last_updated])
    |> validate_required([:quantity, :average_cost, :total_cost])
  end
end

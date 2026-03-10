defmodule StockAnalysis.PaperTrading.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  alias StockAnalysis.PaperTrading.Portfolio

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "paper_transactions" do
    field :ticker, :string
    field :transaction_type, :string
    field :quantity, :decimal
    field :price_per_share, :decimal
    field :total_amount, :decimal
    field :recommendation_at_time, :string
    field :notes, :string
    field :executed_at, :utc_datetime

    belongs_to :portfolio, Portfolio

    timestamps(type: :utc_datetime)
  end

  def create_changeset(transaction, attrs, portfolio_id) do
    transaction
    |> cast(attrs, [
      :ticker,
      :transaction_type,
      :quantity,
      :price_per_share,
      :total_amount,
      :recommendation_at_time,
      :notes,
      :executed_at
    ])
    |> validate_required([
      :ticker,
      :transaction_type,
      :quantity,
      :price_per_share,
      :total_amount,
      :executed_at
    ])
    |> put_change(:portfolio_id, portfolio_id)
    |> validate_inclusion(:transaction_type, ["buy", "sell"])
    |> foreign_key_constraint(:portfolio_id)
    |> update_change(:ticker, &String.upcase/1)
  end
end

defmodule StockAnalysis.PaperTrading.Portfolio do
  use Ecto.Schema
  import Ecto.Changeset

  alias StockAnalysis.Accounts.User
  alias StockAnalysis.PaperTrading.{Holding, Transaction}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "paper_portfolios" do
    field :name, :string
    field :description, :string
    field :starting_balance, :decimal, default: Decimal.new("100000")
    field :cash_balance, :decimal
    field :is_active, :boolean, default: true

    belongs_to :user, User
    has_many :holdings, Holding
    has_many :transactions, Transaction

    timestamps(type: :utc_datetime)
  end

  def create_changeset(portfolio, attrs, user_id) do
    portfolio
    |> cast(attrs, [:name, :description, :starting_balance, :is_active])
    |> validate_required([:name])
    |> default_starting_balance()
    |> validate_number(:starting_balance,
         greater_than: Decimal.new(0),
         less_than_or_equal_to: Decimal.new("1000000000")
       )
    |> put_change(:user_id, user_id)
    |> foreign_key_constraint(:user_id)
    |> set_initial_cash_balance()
  end

  def changeset(portfolio, attrs) do
    portfolio
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
  end

  defp default_starting_balance(changeset) do
    case get_field(changeset, :starting_balance) do
      nil -> put_change(changeset, :starting_balance, Decimal.new("100000"))
      _ -> changeset
    end
  end

  defp set_initial_cash_balance(changeset) do
    case get_field(changeset, :cash_balance) do
      nil ->
        starting = get_field(changeset, :starting_balance) || Decimal.new("100000")
        put_change(changeset, :cash_balance, starting)

      _existing ->
        changeset
    end
  end
end

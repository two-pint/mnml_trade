defmodule StockAnalysis.PaperTrading do
  alias StockAnalysis.Repo
  alias StockAnalysis.PaperTrading.Portfolio

  import Ecto.Query

  def create_portfolio(user_id, attrs) do
    %Portfolio{}
    |> Portfolio.create_changeset(attrs, user_id)
    |> Repo.insert()
  end

  def list_portfolios(user_id) do
    from(p in Portfolio,
      where: p.user_id == ^user_id and p.is_active == true,
      preload: [:holdings],
      order_by: [desc: p.inserted_at]
    )
    |> Repo.all()
  end

  def get_portfolio(user_id, portfolio_id) do
    case Repo.one(
           from(p in Portfolio,
             where: p.id == ^portfolio_id and p.user_id == ^user_id,
             preload: [:holdings]
           )
         ) do
      nil -> {:error, :not_found}
      portfolio -> {:ok, portfolio}
    end
  end

  def update_portfolio(user_id, portfolio_id, attrs) do
    with {:ok, portfolio} <- get_portfolio(user_id, portfolio_id) do
      portfolio
      |> Portfolio.changeset(attrs)
      |> Repo.update()
    end
  end

  def delete_portfolio(user_id, portfolio_id) do
    with {:ok, portfolio} <- get_portfolio(user_id, portfolio_id) do
      Repo.delete(portfolio)
    end
  end
end

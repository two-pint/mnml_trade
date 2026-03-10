defmodule StockAnalysisWeb.PortfolioController do
  use StockAnalysisWeb, :controller

  alias StockAnalysis.PaperTrading

  action_fallback StockAnalysisWeb.FallbackController

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    portfolios = PaperTrading.list_portfolios(user.id)

    conn
    |> put_status(:ok)
    |> render(:index, portfolios: portfolios)
  end

  def create(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, portfolio} <- PaperTrading.create_portfolio(user.id, params) do
      portfolio = StockAnalysis.Repo.preload(portfolio, :holdings)

      conn
      |> put_status(:created)
      |> render(:show, portfolio: portfolio)
    end
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, portfolio} <- PaperTrading.get_portfolio(user.id, id) do
      conn
      |> put_status(:ok)
      |> render(:show, portfolio: portfolio)
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, portfolio} <- PaperTrading.update_portfolio(user.id, id, params) do
      portfolio = StockAnalysis.Repo.preload(portfolio, :holdings)

      conn
      |> put_status(:ok)
      |> render(:show, portfolio: portfolio)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, _portfolio} <- PaperTrading.delete_portfolio(user.id, id) do
      send_resp(conn, :no_content, "")
    end
  end
end

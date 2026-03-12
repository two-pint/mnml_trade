defmodule StockAnalysisWeb.Router do
  use StockAnalysisWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug StockAnalysisWeb.Plugs.AuthPipeline
  end

  # Public routes — no JWT required
  scope "/api", StockAnalysisWeb do
    pipe_through :api

    get "/health", HealthController, :index

    scope "/auth" do
      post "/register", AuthController, :register
      post "/login", AuthController, :login
      post "/refresh", AuthController, :refresh
      post "/forgot-password", AuthController, :forgot_password
      post "/reset-password", AuthController, :reset_password
    end
  end

  # Protected routes — valid JWT required
  scope "/api", StockAnalysisWeb do
    pipe_through [:api, :authenticated]

    get "/user/me", UserController, :me
    get "/user/watchlist", EngagementController, :list_watchlist
    post "/user/watchlist", EngagementController, :add_to_watchlist
    delete "/user/watchlist/:ticker", EngagementController, :remove_from_watchlist
    get "/user/history", EngagementController, :list_history

    get "/stocks/search", StocksController, :search
    get "/stocks/trending", StocksController, :trending
    get "/stocks/:ticker/technical", StocksController, :technical
    get "/stocks/:ticker/fundamental", StocksController, :fundamental
    get "/stocks/:ticker/sentiment", StocksController, :sentiment
    get "/stocks/:ticker/daily", StocksController, :daily
    get "/stocks/:ticker/institutional", StocksController, :institutional
    get "/stocks/:ticker", StocksController, :show

    get "/institutional/:ticker/congressional", InstitutionalController, :congressional
    get "/institutional/:ticker/insider-trades", InstitutionalController, :insider_trades
    get "/institutional/:ticker/holdings", InstitutionalController, :holdings
    get "/institutional/:ticker/smart-money-score", InstitutionalController, :smart_money_score
    get "/institutional/market-tide", InstitutionalController, :market_tide

    resources "/paper-trading/portfolios", PortfolioController, only: [:index, :create, :show, :update, :delete]
    post "/paper-trading/portfolios/:portfolio_id/trade", PortfolioController, :trade
    get "/paper-trading/portfolios/:portfolio_id/holdings", PortfolioController, :holdings
    get "/paper-trading/portfolios/:portfolio_id/transactions", PortfolioController, :transactions
    get "/paper-trading/portfolios/:portfolio_id/transactions/:transaction_id", PortfolioController, :transaction_detail
    get "/paper-trading/portfolios/:portfolio_id/performance", PortfolioController, :performance
  end
end

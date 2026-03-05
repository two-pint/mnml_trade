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

    get "/stocks/search", StocksController, :search
    get "/stocks/:ticker", StocksController, :show
  end
end

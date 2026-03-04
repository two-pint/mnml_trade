defmodule StockAnalysisWeb.Router do
  use StockAnalysisWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

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
end

defmodule StockAnalysisWeb.Router do
  use StockAnalysisWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", StockAnalysisWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end
end

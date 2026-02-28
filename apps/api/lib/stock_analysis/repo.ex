defmodule StockAnalysis.Repo do
  use Ecto.Repo,
    otp_app: :stock_analysis,
    adapter: Ecto.Adapters.Postgres
end

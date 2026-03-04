defmodule StockAnalysisWeb.Plugs.Cors do
  @behaviour Plug

  @impl Plug
  def init(_opts), do: []

  @impl Plug
  def call(conn, _opts) do
    opts =
      :stock_analysis
      |> Application.get_env(:cors, [])
      |> Corsica.init()

    Corsica.call(conn, opts)
  end
end

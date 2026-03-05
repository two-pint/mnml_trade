defmodule StockAnalysis.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      StockAnalysisWeb.Telemetry,
      StockAnalysis.Repo,
      StockAnalysis.Cache,
      {DNSCluster, query: Application.get_env(:stock_analysis, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: StockAnalysis.PubSub},
      # Start a worker by calling: StockAnalysis.Worker.start_link(arg)
      # {StockAnalysis.Worker, arg},
      # Start to serve requests, typically the last entry
      StockAnalysisWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StockAnalysis.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    StockAnalysisWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :stock_analysis,
  ecto_repos: [StockAnalysis.Repo],
  generators: [timestamp_type: :utc_datetime]

# Cache default TTLs (seconds): price 15s, technical 1h, institutional 1h
config :stock_analysis, :cache_default_ttls, %{
  price: 15,
  technical: 3600,
  institutional: 3600
}

# Configure the endpoint
config :stock_analysis, StockAnalysisWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: StockAnalysisWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: StockAnalysis.PubSub,
  live_view: [signing_salt: "8LD/kmmd"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Guardian JWT configuration
config :stock_analysis, StockAnalysis.Guardian,
  issuer: "stock_analysis",
  secret_key: "dev-only-secret-key-replace-in-production",
  ttl: {7, :day}

# CORS configuration
config :stock_analysis, :cors,
  origins: [
    ~r/^http:\/\/localhost:\d+$/,
    ~r/^https:\/\/.*\.vercel\.app$/
  ],
  allow_headers: ["authorization", "content-type", "accept"],
  allow_methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  allow_credentials: true

# Oban job processing
config :stock_analysis, Oban,
  repo: StockAnalysis.Repo,
  queues: [data_refresh: 3, sync: 5, default: 10],
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"*/30 8-16 * * 1-5", StockAnalysis.Workers.ScheduleRefresh, args: %{period: "market"}},
       {"0 */2 * * *", StockAnalysis.Workers.ScheduleRefresh, args: %{period: "off_hours"}},
       {"*/15 8-16 * * 1-5", StockAnalysis.Workers.CheckAlerts},
       {"0 0 * * 0", StockAnalysis.Workers.SeedTickersJob},
       {"0 21 * * 1-5", StockAnalysis.Workers.PriceSnapshotJob},
       {"0 22 * * 1-5", StockAnalysis.Workers.ScoreSnapshotJob}
     ]}
  ]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

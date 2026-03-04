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
  ttl: {1, :hour}

# CORS configuration
config :stock_analysis, :cors,
  origins: [
    "http://localhost:3000",
    "http://localhost:8081",
    ~r/^https:\/\/.*\.vercel\.app$/
  ],
  allow_headers: ["authorization", "content-type", "accept"],
  allow_methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  allow_credentials: true

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

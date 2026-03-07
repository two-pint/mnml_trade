import Config

# Alpha Vantage API key (optional in dev/test; set ALPHA_VANTAGE_API_KEY or config)
if System.get_env("ALPHA_VANTAGE_API_KEY") do
  config :stock_analysis, :alpha_vantage_api_key, System.get_env("ALPHA_VANTAGE_API_KEY")
end

# Unusual Whales API key (optional in dev/test; set UNUSUAL_WHALES_API_KEY or config)
if System.get_env("UNUSUAL_WHALES_API_KEY") do
  config :stock_analysis, :unusual_whales_api_key, System.get_env("UNUSUAL_WHALES_API_KEY")
end

# FMP API key (optional in dev/test; set FMP_API_KEY or config)
if System.get_env("FMP_API_KEY") do
  config :stock_analysis, :fmp_api_key, System.get_env("FMP_API_KEY")
end

# Finnhub API key (optional in dev/test; set FINNHUB_API_KEY or config)
if System.get_env("FINNHUB_API_KEY") do
  config :stock_analysis, :finnhub_api_key, System.get_env("FINNHUB_API_KEY")
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/stock_analysis start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :stock_analysis, StockAnalysisWeb.Endpoint, server: true
end

config :stock_analysis, StockAnalysisWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :stock_analysis, StockAnalysis.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :stock_analysis, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  guardian_secret =
    System.get_env("GUARDIAN_SECRET_KEY") ||
      raise """
      environment variable GUARDIAN_SECRET_KEY is missing.
      You can generate one by calling: mix guardian.gen.secret
      """

  config :stock_analysis, StockAnalysis.Guardian,
    secret_key: guardian_secret

  cors_origins =
    case System.get_env("CORS_ORIGINS") do
      nil -> ["https://#{host}"]
      origins -> String.split(origins, ",", trim: true)
    end

  config :stock_analysis, :cors,
    origins: cors_origins,
    allow_headers: ["authorization", "content-type", "accept"],
    allow_methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_credentials: true

  config :stock_analysis, StockAnalysisWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :stock_analysis, StockAnalysisWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :stock_analysis, StockAnalysisWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end

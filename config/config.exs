# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :pulse_ops,
  ecto_repos: [PulseOps.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  api_rate_limit: %{limit: 240, window_ms: 60_000}

config :pulse_ops, Oban,
  repo: PulseOps.Repo,
  engine: Oban.Engines.Basic,
  queues: [control: 5],
  plugins: [{Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}]

# Configure the endpoint
config :pulse_ops, PulseOpsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: PulseOpsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PulseOps.PubSub,
  live_view: [signing_salt: "BcaKPdwu"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :correlation_id, :organization_id, :job_id, :queue]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :none

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

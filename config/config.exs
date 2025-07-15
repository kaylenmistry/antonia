# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :antonia,
  ecto_repos: [Antonia.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  content_security_policy: [
    "default-src 'self' 'unsafe-eval'",
    "img-src 'self'",
    "style-src 'self' 'unsafe-inline'",
    "font-src 'self'",
    "connect-src 'self'",
    "script-src-elem 'self'"
  ]

# Configures the endpoint
config :antonia, AntoniaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AntoniaWeb.ErrorHTML, json: AntoniaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Antonia.PubSub,
  live_view: [signing_salt: "nY+dmTOa"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :antonia, Antonia.Mailer, adapter: Resend.Swoosh.Adapter

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, local: false

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  antonia: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  antonia: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: {AntoniaApp.Logger.Formatter, :format},
  metadata: :all,
  utc_log: true

config :antonia, AntoniaApp.Logger.Formatter,
  exclude: [
    :erl_level,
    :application,
    :file,
    :function,
    :gl,
    :line,
    :mfa,
    :module,
    :pid
  ]

config :phoenix,
  logger: false,
  # Use Jason for JSON parsing in Phoenix
  json_library: Jason,
  # Filter sensitive data from logs
  filter_parameters: ["password", "secret", "token"]

config :tesla, :adapter, {Tesla.Adapter.Finch, name: Antonia.Finch, request_timeout: 60_000}

config :antonia, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [mailers: 20],
  repo: Antonia.Repo

# Configure Quantum scheduler
config :antonia, Antonia.Scheduler,
  jobs: [
    # Create monthly reports on 1st of each month at 8 AM
    {"0 8 1 * *", {Antonia.Revenue.ReportService, :create_monthly_reports, []}},
    # Send initial monthly reminders on 1st of each month at 9 AM
    {"0 9 1 * *", {Antonia.Revenue.ReportService, :send_initial_reminders, []}},
    # Check for follow-up reminders daily at 10 AM
    {"0 10 * * *", {Antonia.Revenue.ReportService, :send_daily_reminders, []}}
  ]

config :logger, level: :info

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

import Config

config :antonia, AntoniaWeb.Endpoint,
  server: true,
  cache_static_manifest: "priv/static/cache_manifest.json"

config :antonia, Antonia.Repo,
  ssl: true,
  ssl_opts: [
    verify: :verify_none
  ]

config :antonia, Antonia.Mailer, adapter: Resend.Swoosh.Adapter

config :swoosh, local: false

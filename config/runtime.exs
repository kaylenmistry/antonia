import Config
import AntoniaApp.Config

for_env = fn default, overrides -> Keyword.get(overrides, config_env(), default) end

default_db_partition = for_env.("", test: System.get_env("MIX_TEST_PARTITION"))

default_db_name = "antonia_#{config_env()}#{default_db_partition}"
default_db_url = "postgres://postgres:postgres@localhost:5432/#{default_db_name}"

config :antonia, Antonia.Repo,
  log: false,
  url: get_database_url(default_db_url),
  pool_size: get_integer("POOL_SIZE", 10),
  adapter: Ecto.Adapters.Postgres

port = for_env.(4000, test: 4100)
base_url = get_string("BASE_URL", "http://localhost:#{port}")
target_host = for_env.("localhost", test: "www.example.com")

config :antonia, AntoniaWeb.Endpoint,
  url: [host: get_string("PHX_HOST", target_host)],
  http: [
    port: get_integer("PORT", port)
  ],
  check_origin: get_string("CHECK_ORIGIN", "//127.0.0.1,//localhost") |> String.split(","),
  live_view: [signing_salt: get_string("LIVE_VIEW_SIGNING_SALT", "5Pvugx1k")],
  secret_key_base:
    get_string(
      "SECRET_KEY_BASE",
      "EzsV3Yb+cw62e0iLYo92zUsr98bHZWZgORzyWDgS/QVlVDkHYoCbguh2KcBM3i0e"
    ),
  base_url: base_url

config :antonia, AntoniaWeb.O11Y.Endpoint,
  port: get_integer("O11Y_PORT", for_env.(3999, test: 4999))

config :antonia, Antonia.Mailer,
  api_key: get_string("RESEND_API_KEY", "re_JToSkskJ_4oQcGmUfxtCKDkaR9Q2QsXYu")

config :antonia, Antonia.Accounts.UserNotifier, base_url: base_url

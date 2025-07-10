defmodule Antonia.MixProject do
  use Mix.Project

  def project do
    [
      app: :antonia,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {AntoniaApp, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "dev"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bandit, "~> 1.5"},
      {:dns_cluster, "~> 0.1.1"},
      {:ecto_sql, "~> 3.10"},
      {:finch, "~> 0.13"},
      {:gettext, "~> 0.26"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:jason, "~> 1.2"},
      {:logfmt, "~> 3.3"},
      {:mjml, "~> 5.0"},
      {:oban, "~> 2.19"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix, "~> 1.7.21"},
      {:postgrex, ">= 0.0.0"},
      {:prom_ex, "~> 1.11.0"},
      {:resend, "~> 0.4.0"},
      {:salad_ui, "~> 1.0.0-beta.3"},
      {:swoosh, "~> 1.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:tesla, "~> 1.4"},
      {:uniq, "~> 0.1"},
      # Dev and test dependencies
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:ex_machina, "~> 2.8.0", only: [:dev, :test]},
      {:excoveralls, "~> 0.14", only: :test},
      {:floki, ">= 0.30.0", only: :test},
      {:igniter, "~> 0.5"},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:tailwind, "~> 0.3.1", runtime: Mix.env() == :dev},
      {:typed_ecto_schema, "~> 0.4.1", runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "gettext.update": ["gettext.extract", "gettext.merge priv/gettext/"],
      "assets.setup": [
        "tailwind.install --if-missing",
        "esbuild.install --if-missing",
        "cmd yarn --cwd assets/"
      ],
      "assets.build": ["tailwind antonia", "esbuild antonia"],
      "assets.deploy": [
        "tailwind antonia --minify",
        "esbuild antonia --minify",
        "phx.digest"
      ]
    ]
  end
end

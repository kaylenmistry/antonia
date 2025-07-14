defmodule AntoniaApp do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    :ok = AntoniaApp.Logger.start()

    children = [
      AntoniaApp.PromEx,
      AntoniaWeb.Telemetry,
      Antonia.Repo,
      {Phoenix.PubSub, name: Antonia.PubSub},
      {Oban, Application.fetch_env!(:antonia, Oban)},
      Antonia.Scheduler,
      {Finch, name: Antonia.Finch},
      AntoniaWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Antonia.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    AntoniaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

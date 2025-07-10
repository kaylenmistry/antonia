defmodule AntoniaApp.PromEx do
  @moduledoc """
  PromEx configuration for exposing application metrics with Prometheus
  """

  use PromEx, otp_app: :antonia

  alias PromEx.Plugins

  @impl PromEx
  def plugins do
    [
      Plugins.Beam,
      {Plugins.Phoenix, router: AntoniaWeb.Router},
      Plugins.PhoenixLiveView,
      {Plugins.Ecto, otp_app: :antonia, repos: [Antonia.Repo]}
    ]
  end

  @impl PromEx
  def dashboard_assigns do
    [
      datasource_id: "prometheus"
    ]
  end

  @impl PromEx
  def dashboards do
    [
      # PromEx built in Grafana dashboards
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "phoenix_live_view.json"},
      {:prom_ex, "ecto.json"}
    ]
  end
end

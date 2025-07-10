defmodule AntoniaWeb.O11Y.Endpoint do
  @moduledoc """
  Plug Router for exposing metrics and health endpoints on a private port,
  separate from our public Phoenix endpoint, such that they are not exposed publicly
  """
  use Plug.Builder

  # Health endpoints for liveness and readiness
  plug AntoniaWeb.O11Y.Health
  # Metrics endpoint
  plug PromEx.Plug, prom_ex_module: AntoniaApp.PromEx
  plug :not_found

  @doc false
  def not_found(conn, _opts) do
    send_resp(conn, 404, "not found")
  end

  @doc "O11Y Endpoint child spec"
  @spec child_spec(any()) :: Supervisor.child_spec()
  def child_spec(_) do
    Supervisor.child_spec(
      {Plug.Cowboy, scheme: :http, plug: __MODULE__, options: [port: config()[:port]]},
      []
    )
  end

  @spec config :: Keyword.t()
  defp config do
    Application.get_env(:Antonia, __MODULE__, [])
  end
end

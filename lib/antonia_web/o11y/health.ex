defmodule AntoniaWeb.O11Y.Health do
  @moduledoc """
  Expose health checks as HTTP endpoints
  """

  @behaviour Plug

  import Plug.Conn

  alias Antonia.Health

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{} = conn, _opts) do
    case conn.request_path do
      "/health/liveness" ->
        health_response(conn, Health.alive?())

      "/health/readiness" ->
        health_response(conn, Health.ready?())

      _other ->
        conn
    end
  end

  @spec health_response(Plug.Conn.t(), boolean()) :: Plug.Conn.t()
  defp health_response(conn, true) do
    conn
    |> send_resp(200, "OK")
    |> halt()
  end

  defp health_response(conn, false) do
    conn
    |> send_resp(503, "Service unavailable")
    |> halt()
  end
end

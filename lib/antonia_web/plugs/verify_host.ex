defmodule AntoniaWeb.Plugs.VerifyHost do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _) do
    if conn.host != host() do
      conn
      |> put_resp_header("location", base_url() <> conn.request_path)
      |> send_resp(301, "")
      |> halt()
    else
      conn
    end
  end

  ### Config ###

  @spec base_url :: String.t()
  defp base_url do
    AntoniaWeb.Endpoint.config(:base_url)
  end

  @spec host :: String.t()
  defp host do
    AntoniaWeb.Endpoint.config(:url)[:host]
  end
end

defmodule AntoniaWeb.Plugs.RedirectAuthenticatedUser do
  @moduledoc false

  @behaviour Plug

  import Phoenix.Controller, only: [redirect: 2]
  import Plug.Conn

  alias Ueberauth.Auth

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _) do
    conn = fetch_cookies(conn)

    case get_session(conn, :auth) do
      %Auth{} -> conn |> redirect(to: "/app") |> halt()
      _ -> conn
    end
  end
end

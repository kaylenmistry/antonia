defmodule AntoniaWeb.Plugs.RedirectAuthenticatedUser do
  @moduledoc false

  @behaviour Plug

  use Phoenix.VerifiedRoutes,
    endpoint: AntoniaWeb.Endpoint,
    router: AntoniaWeb.Router,
    statics: AntoniaWeb.static_paths()

  import Phoenix.Controller, only: [redirect: 2]
  import Plug.Conn

  alias Ueberauth.Auth

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _) do
    conn = fetch_cookies(conn)

    case get_session(conn, :auth) do
      %Auth{} -> conn |> redirect(to: ~p"/app") |> halt()
      _ -> conn
    end
  end
end

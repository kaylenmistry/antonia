defmodule AntoniaWeb.Plugs.RequireAuthenticatedUser do
  @moduledoc false

  @behaviour Plug

  use Phoenix.VerifiedRoutes,
    endpoint: AntoniaWeb.Endpoint,
    router: AntoniaWeb.Router,
    statics: AntoniaWeb.static_paths()

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2, current_path: 1]

  alias Antonia.Services.Kinde
  alias Ueberauth.Auth

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _) do
    conn = fetch_cookies(conn)

    with %Auth{} = auth <- get_session(conn, :auth),
         {:ok, refreshed_auth} <- Kinde.maybe_refresh_token(auth) do
      put_session(conn, :auth, refreshed_auth)
    else
      _ ->
        conn
        |> clear_session()
        |> maybe_store_return_to()
        |> redirect(to: ~p"/auth/login")
        |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn
end

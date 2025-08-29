defmodule AntoniaWeb.Plugs.RequireAuthenticatedUser do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2, current_path: 1]
  alias Ueberauth.Auth

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _) do
    conn = fetch_cookies(conn)

    case get_session(conn, :auth) do
      %Auth{provider: provider, credentials: %Auth.Credentials{expires_at: expires_at}} ->
        if DateTime.compare(DateTime.utc_now(), DateTime.from_unix!(expires_at)) == :lt do
          conn
        else
          conn
          |> clear_session()
          |> maybe_store_return_to()
          |> redirect(to: "/auth/#{provider}")
          |> halt()
        end

      _ ->
        conn
        |> maybe_store_return_to()
        |> redirect(to: "/auth")
        |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn
end

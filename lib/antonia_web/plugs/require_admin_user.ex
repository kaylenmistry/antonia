defmodule AntoniaWeb.Plugs.RequireAdminUser do
  @moduledoc """
  Plug that ensures the current user is an admin.
  If not, redirects to the home page.
  """

  @behaviour Plug

  use Phoenix.VerifiedRoutes,
    endpoint: AntoniaWeb.Endpoint,
    router: AntoniaWeb.Router,
    statics: AntoniaWeb.static_paths()

  import Phoenix.Controller, only: [redirect: 2, current_path: 1, put_flash: 3]
  import Plug.Conn

  alias Ueberauth.Auth

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _) do
    conn = fetch_cookies(conn)

    case get_session(conn, :auth) do
      %Auth{info: %Auth.Info{email: email}} when is_binary(email) ->
        if authorised?(email) do
          conn
        else
          conn
          |> maybe_store_return_to()
          |> put_flash(:error, "Access denied. Admin privileges required.")
          |> redirect(to: ~p"/")
          |> halt()
        end

      _ ->
        conn
        |> maybe_store_return_to()
        |> put_flash(:error, "Please log in to access admin area.")
        |> redirect(to: ~p"/auth/login")
        |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  # Allow specific emails to access admin features
  @spec authorised?(String.t()) :: boolean()
  defp authorised?(email) when is_binary(email) do
    Enum.member?(authorised_emails(), email)
  end

  ##### Config #####

  @spec authorised_emails() :: [String.t()]
  defp authorised_emails do
    Application.get_env(:antonia, __MODULE__, [])[:authorised_users] || []
  end
end

defmodule AntoniaWeb.AuthController do
  @moduledoc false
  use AntoniaWeb, :controller

  plug Ueberauth

  require Logger

  alias Antonia.Accounts
  alias Antonia.Accounts.User
  alias Antonia.Services.Kinde

  @doc """
  Redirects to Kinde login page with nonce parameter.
  """
  def login(conn, _params) do
    nonce = generate_nonce()

    conn
    |> put_session(:oauth_nonce, nonce)
    |> redirect(to: "/auth/kinde?prompt=login&nonce=#{nonce}")
  end

  @doc """
  Redirects to Kinde registration page with nonce parameter.
  """
  def register(conn, _params) do
    nonce = generate_nonce()

    conn
    |> put_session(:oauth_nonce, nonce)
    |> redirect(to: "/auth/kinde?prompt=create&nonce=#{nonce}")
  end

  @doc false
  def index(conn, _params) do
    render(conn, "index.html", layout: false, no_footer: true)
  end

  @doc """
  Logs out from both local session and Kinde, then redirects to home page.
  """
  def logout(conn, _params) do
    if live_socket_id = get_session(conn, :live_socket_id) do
      AntoniaWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> redirect(external: Kinde.get_logout_url())
  end

  @doc false
  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user_return_to = get_session(conn, :user_return_to)
    account_id = get_session(conn, :account_id)

    {:ok, %User{id: user_id}} = maybe_register_user(auth)

    # Use local user id and remove extra claims and large tokens
    auth =
      auth
      |> Map.put(:uid, user_id)
      |> Map.put(:extra, nil)
      |> Map.put(:credentials, %{auth.credentials | other: %{}})

    conn
    |> renew_session()
    |> put_session(:auth, auth)
    |> put_session(:account_id, account_id)
    |> put_session(:live_socket_id, "users_sessions:#{user_id}")
    |> redirect(to: user_return_to || ~p"/app")
  end

  @spec renew_session(Plug.Conn.t()) :: Plug.Conn.t()
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  # Domain helpers

  @spec maybe_register_user(Ueberauth.Auth.t()) :: {:ok, User.t()} | {:error, atom()}
  defp maybe_register_user(auth) do
    %{
      uid: auth.uid,
      provider: auth.provider,
      email: auth.info.email,
      first_name: auth.info.first_name,
      last_name: auth.info.last_name,
      image: auth.info.image
    }
    |> Map.filter(fn {_k, v} -> !is_nil(v) end)
    |> Accounts.create_or_update_user()
  end

  defp generate_nonce do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end

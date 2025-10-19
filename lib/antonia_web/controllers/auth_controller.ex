defmodule AntoniaWeb.AuthController do
  @moduledoc false
  use AntoniaWeb, :controller

  plug Ueberauth

  require Logger

  alias Ueberauth.Auth

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
  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user_return_to = get_session(conn, :user_return_to)

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
    |> put_session(:live_socket_id, "users_sessions:#{user_id}")
    |> redirect(to: user_return_to || ~p"/app")
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
    |> redirect(external: get_logout_url())
  end

  @doc """
  Redirects user to Kinde self-serve portal for user profile settings.
  """
  def account_settings(conn, _params) do
    with %Auth{credentials: %Auth.Credentials{token: access_token}} <- get_session(conn, :auth),
         return_url <- "#{get_base_url()}/app",
         {:ok, portal_url} <- Kinde.generate_portal_link(access_token, return_url: return_url) do
      redirect(conn, external: portal_url)
    else
      {:error, reason} ->
        Logger.error("operation=open_account_settings error=#{inspect(reason)}")

        conn
        |> put_flash(:error, gettext("An error occurred, please try again."))
        |> redirect(to: "/app")

      _ ->
        Logger.error("operation=open_account_settings message=no_access_token")

        conn
        |> put_flash(:error, gettext("An error occurred, please try again."))
        |> redirect(to: "/auth/login")
    end
  end

  ##### Helper functions #####

  @spec renew_session(Plug.Conn.t()) :: Plug.Conn.t()
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @spec generate_nonce() :: String.t()
  defp generate_nonce do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end

  @spec get_logout_url() :: String.t()
  defp get_logout_url do
    kinde_domain =
      Application.get_env(:ueberauth, Ueberauth.Strategy.Kinde.OAuth)[:domain]

    "#{kinde_domain}/logout?redirect=#{URI.encode(get_base_url())}"
  end

  @spec get_base_url :: String.t()
  defp get_base_url do
    Application.get_env(:antonia, AntoniaWeb.Endpoint)[:base_url]
  end

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
end

defmodule Ueberauth.Strategy.Kinde do
  @moduledoc """
  Kinde Strategy for Überauth.
  """

  use Ueberauth.Strategy,
    uid_field: :id,
    default_scope: "openid profile email offline",
    userinfo_endpoint: nil

  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra
  alias Ueberauth.Auth.Info
  alias Ueberauth.Strategy.Kinde.OAuth

  @doc """
  Handles initial request for Kinde authentication.
  """
  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)

    params =
      [scope: scopes]
      |> with_optional(:prompt, conn)
      |> with_optional(:login_hint, conn)
      |> with_optional(:organization, conn)
      |> with_optional(:is_create_org, conn)
      |> with_param(:prompt, conn)
      |> with_param(:login_hint, conn)
      |> with_param(:organization, conn)
      |> with_param(:is_create_org, conn)
      |> with_state_param(conn)

    opts = oauth_client_options_from_conn(conn)
    redirect!(conn, OAuth.authorize_url!(params, opts))
  end

  @doc """
  Handles the callback from Kinde.
  """
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    params = [code: code]
    opts = oauth_client_options_from_conn(conn)

    case OAuth.get_access_token(params, opts) do
      {:ok, token} ->
        fetch_user(conn, token)

      {:error, {error_code, error_description}} ->
        set_errors!(conn, [error(error_code, error_description)])
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc false
  def handle_cleanup!(conn) do
    conn
    |> put_private(:kinde_user, nil)
    |> put_private(:kinde_token, nil)
  end

  @doc """
  Fetches the uid field from the response.
  """
  def uid(conn) do
    uid_field =
      conn
      |> option(:uid_field)
      |> to_string

    conn.private.kinde_user[uid_field]
  end

  @doc """
  Includes the credentials from the kinde response.
  """
  def credentials(conn) do
    token = conn.private.kinde_token

    %Credentials{
      token: token.access_token,
      refresh_token: token.refresh_token,
      expires_at: token.expires_at,
      token_type: Map.get(token, :token_type),
      expires: !!token.expires_at,
      scopes: String.split(token.scope, " "),
      other: %{
        id_token: token.other["id_token"]
      }
    }
  end

  @doc """
  Fetches the fields to populate the info section of the Ueberauth.Auth struct.
  """
  def info(conn) do
    user = conn.private.kinde_user

    %Info{
      email: user["email"],
      first_name: user["given_name"],
      last_name: user["family_name"],
      name: user["name"],
      image: user["picture"]
    }
  end

  @doc """
  Stores the raw information (including the token) obtained from the kinde callback.
  """
  def extra(conn) do
    %Extra{
      raw_info: %{
        token: conn.private.kinde_token,
        user: conn.private.kinde_user
      }
    }
  end

  defp fetch_user(conn, token) do
    conn = put_private(conn, :kinde_token, token)

    case OAuth.get(token, "/oauth2/userinfo") do
      {:ok, %OAuth2.Response{status_code: 401, body: _}} ->
        set_errors!(conn, [error("token", "unauthorized")])

      {:ok, %OAuth2.Response{status_code: status_code, body: user}}
      when status_code in 200..299 ->
        conn
        |> put_private(:kinde_user, user)
        |> put_private(:kinde_token, token)

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])

      {:error, %OAuth2.Response{status_code: status_code}} ->
        set_errors!(conn, [error("OAuth2", "#{status_code}")])
    end
  end

  defp with_param(opts, key, conn) do
    if value = conn.params[to_string(key)], do: Keyword.put(opts, key, value), else: opts
  end

  defp with_optional(opts, key, conn) do
    if option(conn, key), do: Keyword.put(opts, key, option(conn, key)), else: opts
  end

  defp oauth_client_options_from_conn(conn) do
    base_options = [redirect_uri: callback_url(conn)]
    request_options = conn.private[:ueberauth_request_options].options

    case {request_options[:client_id], request_options[:client_secret]} do
      {nil, _} -> base_options
      {_, nil} -> base_options
      {id, secret} -> [client_id: id, client_secret: secret] ++ base_options
    end
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end
end

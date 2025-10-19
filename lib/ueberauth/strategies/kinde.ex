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
    scope_string = token.other_params["scope"] || ""
    scopes = String.split(scope_string, " ")

    %Credentials{
      expires: !!token.expires_at,
      expires_at: token.expires_at,
      scopes: scopes,
      token_type: Map.get(token, :token_type),
      refresh_token: token.refresh_token,
      token: token.access_token,
      other: %{
        id_token: token.other_params["id_token"]
      }
    }
  end

  @doc """
  Fetches the fields to populate the info section of the `Ueberauth.Auth` struct.
  """
  def info(conn) do
    user = conn.private.kinde_user

    %Info{
      email: user["preferred_email"],
      first_name: user["first_name"],
      image: user["picture"],
      last_name: user["last_name"],
      name: name_from_user(user),
      urls: %{
        profile: user["profile"]
      }
    }
  end

  @doc """
  Stores the raw information (including the token) obtained from the kinde callback.
  """
  def extra(conn) do
    %Extra{
      raw_info: %{
        token: conn.private.kinde_token,
        user: conn.private.kinde_user,
        organization: conn.private[:kinde_organization]
      }
    }
  end

  @doc """
  Extracts user information from ID token if available.
  """
  def extract_user_info_from_id_token(%Credentials{other: %{id_token: id_token}})
      when not is_nil(id_token) do
    case decode_jwt(id_token) do
      {:ok, claims} -> claims
      {:error, _reason} -> %{}
    end
  end

  def extract_user_info_from_id_token(_credentials), do: %{}

  @doc """
  Extracts organization information from ID token if available.
  """
  def extract_organization_info_from_id_token(%Credentials{other: %{id_token: id_token}})
      when not is_nil(id_token) do
    case decode_jwt(id_token) do
      {:ok, claims} ->
        %{
          org_code: claims["org_code"],
          org_name: claims["org_name"],
          permissions: claims["permissions"] || []
        }

      {:error, _reason} ->
        %{}
    end
  end

  def extract_organization_info_from_id_token(_credentials), do: %{}

  defp fetch_user(conn, token) do
    conn = put_private(conn, :kinde_token, token)

    # Get userinfo endpoint from configuration or use default
    userinfo_endpoint = get_userinfo_endpoint(conn)

    resp = OAuth.get(token, userinfo_endpoint)

    case resp do
      {:ok, %OAuth2.Response{status_code: 401, body: body}} ->
        set_errors!(conn, [error("token", "unauthorized" <> body)])

      {:ok, %OAuth2.Response{status_code: status_code, body: user}}
      when status_code in 200..399 ->
        conn = put_private(conn, :kinde_user, user)

        # Optionally fetch organization info if available
        fetch_organization_info(conn, token)

      {:error, %OAuth2.Response{status_code: status_code}} ->
        set_errors!(conn, [error("OAuth2", to_string(status_code))])

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp fetch_organization_info(conn, token) do
    domain = option(conn, :domain)
    org_url = "#{domain}/api/v1/organization"

    case OAuth.get(token, org_url) do
      {:ok, %OAuth2.Response{status_code: 200, body: organization}} ->
        put_private(conn, :kinde_organization, organization)

      _ ->
        # Organization info is optional, so we don't fail if it's not available
        conn
    end
  end

  defp get_userinfo_endpoint(conn) do
    case option(conn, :userinfo_endpoint) do
      {:system, varname, default} ->
        System.get_env(varname) || default

      {:system, varname} ->
        System.get_env(varname) || get_default_userinfo_endpoint(conn)

      nil ->
        get_default_userinfo_endpoint(conn)

      other ->
        other
    end
  end

  defp get_default_userinfo_endpoint(conn) do
    domain = option(conn, :domain)
    "#{domain}/oauth2/user_profile"
  end

  defp name_from_user(user) do
    first_name = user["first_name"]
    last_name = user["last_name"]

    case {first_name, last_name} do
      {nil, nil} -> user["name"]
      {first_name, nil} -> first_name
      {nil, last_name} -> last_name
      {first_name, last_name} -> "#{first_name} #{last_name}"
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

  defp decode_jwt(token) do
    # Split JWT into parts
    [_header, payload, _signature] = String.split(token, ".")

    # Decode payload (base64url)
    decoded_payload =
      payload
      |> String.replace("-", "+")
      |> String.replace("_", "/")
      |> Base.decode64!(padding: true)

    claims = Jason.decode!(decoded_payload)
    {:ok, claims}
  rescue
    error -> {:error, error}
  end
end

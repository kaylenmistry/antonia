defmodule Antonia.Services.Kinde.TokenRefresh do
  @moduledoc """
  Service for refreshing Kinde access tokens using OAuth2.Strategy.Refresh.
  """

  require Logger

  alias Ueberauth.Auth
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Strategy.Kinde.OAuth

  @doc """
  Checks if token needs refresh and refreshes if necessary.

  Returns {:ok, auth} if token is valid or successfully refreshed,
  or {:error, reason} if refresh failed or token is invalid.
  """
  @spec maybe_refresh_token(Auth.t()) :: {:ok, Auth.t()} | {:error, atom()}
  def maybe_refresh_token(
        %Auth{credentials: %Credentials{expires_at: expires_at, refresh_token: refresh_token}} =
          auth
      ) do
    cond do
      !token_expired?(expires_at) ->
        {:ok, auth}

      is_nil(refresh_token) ->
        Logger.warning(
          "operation=maybe_refresh_token, error=no_refresh_token, user_id=#{auth.uid}"
        )

        {:error, :no_refresh_token}

      true ->
        case refresh_access_token(refresh_token, auth) do
          {:ok, refreshed_auth} ->
            Logger.info("operation=maybe_refresh_token, success=true, user_id=#{auth.uid}")
            {:ok, refreshed_auth}

          {:error, reason} ->
            Logger.warning(
              "operation=maybe_refresh_token, error=refresh_failed, user_id=#{auth.uid}, reason=#{inspect(reason)}"
            )

            {:error, reason}
        end
    end
  end

  def maybe_refresh_token(_) do
    Logger.warning("operation=maybe_refresh_token, error=invalid_auth")
    {:error, :invalid_auth}
  end

  ##### Private Functions #####

  @spec token_expired?(integer() | nil) :: boolean()
  defp token_expired?(nil), do: true

  defp token_expired?(expires_at) when is_integer(expires_at) do
    DateTime.compare(DateTime.utc_now(), DateTime.from_unix!(expires_at)) != :lt
  end

  @spec refresh_access_token(String.t(), Auth.t()) :: {:ok, Auth.t()} | {:error, atom()}
  defp refresh_access_token(nil, _auth), do: {:error, :no_refresh_token}
  defp refresh_access_token("", _auth), do: {:error, :no_refresh_token}

  defp refresh_access_token(refresh_token, auth) do
    refresh_token
    |> build_refresh_client()
    |> perform_refresh()
    |> handle_refresh_response(auth)
  end

  @spec build_refresh_client(String.t()) :: OAuth2.Client.t()
  defp build_refresh_client(refresh_token) do
    # Reuse the existing OAuth client configuration
    base_client = OAuth.client()

    # Create a new client with refresh strategy
    OAuth2.Client.new(base_client,
      strategy: OAuth2.Strategy.Refresh,
      client_id: base_client.client_id,
      client_secret: base_client.client_secret,
      site: base_client.site,
      params: %{"refresh_token" => refresh_token}
    )
  end

  @spec perform_refresh(OAuth2.Client.t()) :: {:ok, OAuth2.AccessToken.t()} | {:error, any()}
  defp perform_refresh(client) do
    case OAuth2.Client.get_token(client) do
      {:ok, %OAuth2.Client{token: token}} ->
        {:ok, token}

      {:error, %OAuth2.Response{status_code: 401}} ->
        {:error, :refresh_token_expired}

      {:error, %OAuth2.Response{status_code: status_code, body: body}} ->
        Logger.error(
          "operation=handle_refresh_response, error=refresh_failed, status_code=#{status_code}, body=#{inspect(body)}"
        )

        {:error, :refresh_failed}

      {:error, reason} ->
        Logger.error(
          "operation=handle_refresh_response, error=refresh_failed, reason=#{inspect(reason)}"
        )

        {:error, :refresh_failed}
    end
  end

  @spec handle_refresh_response({:ok, OAuth2.AccessToken.t()} | {:error, any()}, Auth.t()) ::
          {:ok, Auth.t()} | {:error, atom()}
  defp handle_refresh_response({:ok, token}, auth) do
    new_auth = build_auth_from_token(token, auth)
    {:ok, new_auth}
  end

  defp handle_refresh_response({:error, reason}, _auth), do: {:error, reason}

  @spec build_auth_from_token(OAuth2.AccessToken.t(), Auth.t()) :: Auth.t()
  def build_auth_from_token(token, auth) do
    # Decode the JSON access_token and create a proper OAuth2.AccessToken
    decoded_token = token.access_token |> Jason.decode!() |> OAuth2.AccessToken.new()

    credentials = %Credentials{
      expires: true,
      expires_at: decoded_token.expires_at,
      scopes: decoded_token.other_params |> Map.get("scope", "") |> String.split(" "),
      token_type: Map.get(decoded_token, :token_type),
      refresh_token: decoded_token.refresh_token,
      token: decoded_token.access_token,
      other: %{}
    }

    # Return the auth with enriched credentials, preserving original user info
    %{auth | credentials: credentials}
  end
end

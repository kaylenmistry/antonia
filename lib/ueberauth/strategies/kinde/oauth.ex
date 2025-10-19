defmodule Ueberauth.Strategy.Kinde.OAuth do
  @moduledoc """
  OAuth2 for Kinde.

  Add `client_id` and `client_secret` to your configuration:

      config :ueberauth, Ueberauth.Strategy.Kinde.OAuth,
        client_id: System.get_env("KINDE_CLIENT_ID"),
        client_secret: System.get_env("KINDE_CLIENT_SECRET"),
        domain: System.get_env("KINDE_DOMAIN")

  """

  use OAuth2.Strategy

  alias OAuth2.Strategy.AuthCode

  @defaults [
    strategy: __MODULE__,
    site: nil,
    authorize_url: "/oauth2/auth",
    token_url: "/oauth2/token"
  ]

  @doc """
  Construct a client for requests to Kinde.

  This will be setup automatically for you in `Ueberauth.Strategy.Kinde`.

  These options are only useful for usage outside the normal callback phase of Ueberauth.
  """
  def client(opts \\ []) do
    config = Application.get_env(:ueberauth, __MODULE__, [])
    json_library = Ueberauth.json_library()

    # Get domain from config or opts
    domain = Keyword.get(opts, :domain) || Keyword.get(config, :domain)

    # Set site based on domain
    site = if domain, do: domain, else: Keyword.get(config, :site)

    @defaults
    |> Keyword.merge(config)
    |> Keyword.merge(opts)
    |> Keyword.put(:site, site)
    |> resolve_values()
    |> generate_secret()
    |> OAuth2.Client.new()
    |> OAuth2.Client.put_serializer("application/json", json_library)
  end

  @doc """
  Provides the authorize url for the request phase of Ueberauth. No need to call this usually.
  """
  def authorize_url!(params \\ [], opts \\ []) do
    opts
    |> client
    |> OAuth2.Client.authorize_url!(params)
  end

  @doc """
  Makes a GET request to the specified URL using the provided token.

  This function is used internally by the Kinde strategy to fetch user information
  and organization data from Kinde's API endpoints.
  """
  def get(token, url, headers \\ [], opts \\ []) do
    [token: token]
    |> client
    |> put_param("client_secret", client().client_secret)
    |> OAuth2.Client.get(url, headers, opts)
  end

  @doc """
  Exchanges an authorization code for an access token.

  This function handles the OAuth2 token exchange process, including error handling
  for various failure scenarios that can occur during the token request.
  """
  def get_access_token(params \\ [], opts \\ []) do
    case opts |> client |> OAuth2.Client.get_token(params) do
      {:error, %OAuth2.Response{body: %{"error" => error}} = response} ->
        description = Map.get(response.body, "error_description", "")
        {:error, {error, description}}

      {:error, %OAuth2.Error{reason: reason}} ->
        {:error, {"error", to_string(reason)}}

      {:ok, %OAuth2.Client{token: token}} ->
        {:ok, token}
    end
  end

  # Strategy Callbacks

  @doc """
  Strategy callback for generating the authorization URL.

  This function is called by the OAuth2 library to generate the authorization URL
  using the AuthCode strategy.
  """
  def authorize_url(client, params) do
    AuthCode.authorize_url(client, params)
  end

  @doc """
  Strategy callback for exchanging authorization code for access token.

  This function is called by the OAuth2 library to perform the token exchange
  using the AuthCode strategy with proper headers and parameters.
  """
  def get_token(client, params, headers) do
    client
    |> put_param("client_secret", client.client_secret)
    |> put_header("Accept", "application/json")
    |> AuthCode.get_token(params, headers)
  end

  defp resolve_values(list) do
    for {key, value} <- list do
      {key, resolve_value(value)}
    end
  end

  defp resolve_value({m, f, a}) when is_atom(m) and is_atom(f), do: apply(m, f, a)
  defp resolve_value(v), do: v

  defp generate_secret(opts) do
    if is_tuple(opts[:client_secret]) do
      {module, fun} = opts[:client_secret]
      secret = apply(module, fun, [opts])
      Keyword.put(opts, :client_secret, secret)
    else
      opts
    end
  end
end

defmodule Antonia.Services.Kinde do
  @moduledoc """
  Kinde API client
  """

  alias Antonia.Services.Kinde.TokenRefresh

  @doc "Kinde configuration."
  @spec config :: map()
  def config do
    Application.get_env(:antonia, __MODULE__)
  end

  @doc "Generate a portal link for the given sub_nav."
  @spec generate_portal_link(String.t(), keyword()) :: {:ok, String.t()} | {:error, atom()}
  def generate_portal_link(_access_token, opts \\ []) do
    domain = config()[:domain]
    sub_nav = Keyword.get(opts, :sub_nav, "profile")

    portal_url = "#{domain}/portal/#{sub_nav}"

    {:ok, portal_url}
  end

  @doc "Get logout URL for Kinde."
  @spec get_logout_url() :: String.t()
  def get_logout_url do
    domain = config()[:domain]
    "#{domain}/logout"
  end

  @doc "Maybe refresh an Auth struct if needed."
  @spec maybe_refresh_token(map()) :: {:ok, map()} | {:error, atom()}
  def maybe_refresh_token(auth) do
    TokenRefresh.maybe_refresh_token(auth)
  end
end

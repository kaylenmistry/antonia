defmodule Antonia.Services.Kinde do
  @moduledoc """
  Kinde API client
  """

  alias Antonia.Services.Kinde.CreateOrganisation
  alias Antonia.Services.Kinde.Portal
  alias Antonia.Services.Kinde.TokenRefresh

  @doc "Kinde configuration."
  @spec config :: map()
  def config do
    Application.get_env(:antonia, __MODULE__)
  end

  @doc "Generate a portal link for the given sub_nav."
  @spec generate_portal_link(String.t(), keyword()) :: {:ok, String.t()} | {:error, atom()}
  def generate_portal_link(access_token, opts \\ []) do
    Portal.generate_link(access_token, opts)
  end

  @doc "Create a new organisation."
  @spec create_organisation(String.t(), map()) :: {:ok, String.t()} | {:error, atom()}
  def create_organisation(access_token, organisation_params) do
    CreateOrganisation.create_organisation(access_token, organisation_params)
  end

  @doc "Maybe refresh an Auth struct if needed."
  @spec maybe_refresh_token(map()) :: {:ok, map()} | {:error, atom()}
  def maybe_refresh_token(auth) do
    TokenRefresh.maybe_refresh_token(auth)
  end
end

defmodule Antonia.Services.Kinde.CreateOrganisation do
  @moduledoc false
  require Logger

  alias Antonia.Services.Kinde

  @doc false
  @spec create_organisation(String.t(), map()) :: {:ok, String.t()} | {:error, atom()}
  def create_organisation(access_token, params) do
    params
    |> make_request(access_token)
    |> handle_response()
  end

  @spec make_request(map(), String.t()) :: Tesla.Env.result()
  defp make_request(body, access_token) do
    Tesla.post(client(), "/api/v1/organizations", body,
      headers: [{"Authorization", "Bearer #{access_token}"}]
    )
  end

  @spec handle_response(Tesla.Env.result()) :: {:ok, String.t()} | {:error, atom()}
  defp handle_response({:ok, %Tesla.Env{status: 200, body: body}}) do
    {:ok, body["organization"]["code"]}
  end

  defp handle_response(tesla_response) do
    tesla_response
    |> inspect()
    |> Logger.warning()

    {:error, :failed_to_create_organisation}
  end

  @spec client() :: Tesla.Client.t()
  defp client do
    Tesla.client([
      {Tesla.Middleware.Telemetry, []},
      {Tesla.Middleware.Timeout, timeout: 10_000},
      {Tesla.Middleware.BaseUrl, Kinde.config()[:domain]},
      Tesla.Middleware.JSON
    ])
  end
end

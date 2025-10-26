defmodule Antonia.Services.Kinde.Portal do
  @moduledoc false
  require Logger

  alias Antonia.Services.Kinde

  @doc false
  @spec generate_link(String.t(), keyword()) :: {:ok, String.t()} | {:error, atom()}
  def generate_link(access_token, opts \\ []) do
    %{sub_nav: opts[:sub_nav] || :profile, return_url: opts[:return_url]}
    |> make_request(access_token)
    |> handle_response()
  end

  @spec make_request(map(), String.t()) :: Tesla.Env.result()
  defp make_request(params, access_token) do
    query_string = URI.encode_query(params)
    url = "/account_api/v1/portal_link?#{query_string}"

    Tesla.get(client(), url, headers: [{"Authorization", "Bearer #{access_token}"}])
  end

  @spec handle_response(Tesla.Env.result()) :: {:ok, String.t()} | {:error, atom()}
  defp handle_response({:ok, %Tesla.Env{status: 200, body: body}}) do
    {:ok, body["url"]}
  end

  defp handle_response(tesla_response) do
    tesla_response
    |> inspect()
    |> Logger.warning()

    {:error, :failed_to_generate_portal_link}
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

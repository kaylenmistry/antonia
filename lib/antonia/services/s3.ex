defmodule Antonia.Services.S3 do
  @moduledoc """
  Functions for interacting with files in S3.
  """

  require Logger

  alias Phoenix.Socket

  ##### S3 Functionality #####

  @doc """
  Presigns a read url for a given s3 key
  """
  @spec presign_read(String.t()) :: {:ok, binary()} | {:error, binary()}
  def presign_read(s3_key) do
    config = ExAws.Config.new(:s3, region: config()[:aws_region])
    bucket = config()[:s3_bucket_name]

    case ExAws.S3.presigned_url(config, :get, bucket, s3_key, expires_in: 120) do
      {:ok, url} ->
        {:ok, url}

      {:error, error} ->
        Logger.error("operation=presign_read, error=#{inspect(error)}, s3_key=#{s3_key}")
        {:error, error}
    end
  end

  @doc """
  Presigns a write url for a given s3 key
  """
  @spec presign_upload(map(), Socket.t()) :: {:ok, map(), Socket.t()} | {:error, binary()}
  def presign_upload(entry, socket) do
    config = ExAws.Config.new(:s3, region: config()[:aws_region])
    bucket = config()[:s3_bucket_name]

    key = s3_key(entry, socket.assigns.user_id)

    case ExAws.S3.presigned_url(config, :put, bucket, key,
           expires_in: 600,
           query_params: [{"Content-Type", entry.client_type}]
         ) do
      {:ok, url} ->
        {:ok, %{uploader: "S3", key: key, url: url}, socket}

      {:error, error} ->
        Logger.error("Failed to generate presigned upload url: #{inspect(error)}")
        {:error, error}
    end
  end

  @spec s3_key(map(), String.t()) :: String.t()
  defp s3_key(entry, user_id), do: "private/reports/#{user_id}/#{entry.client_name}"

  ##### Config #####

  defp config, do: Application.get_env(:antonia, __MODULE__)
end

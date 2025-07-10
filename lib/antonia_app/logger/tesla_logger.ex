defmodule AntoniaApp.Logger.TeslaLogger do
  @moduledoc """
  Defines and attaches event handlers to telemetry events.
  These handlers define better structured logs with information more concise and creating less noise when logging.
  """
  require Logger

  @doc false
  def start do
    handlers = %{
      [:tesla, :request, :stop] => &__MODULE__.tesla_request_stop/4
    }

    for {key, fun} <- handlers do
      :telemetry.attach({__MODULE__, key}, key, fun, :ok)
    end
  end

  defp convert_system_time(time) do
    System.convert_time_unit(time, :native, :microsecond)
  end

  @doc """
  Listen for events related to Tesla requests.
  """
  def tesla_request_stop(_, %{duration: time}, %{env: tesla_env}, _) do
    %{method: method, status: status, url: url} = tesla_env

    metadata =
      tesla_env
      |> Map.take([:headers, :opts, :query])
      |> Map.put(:duration, convert_system_time(time))

    Logger.info("#{method} #{url} -> #{status}", metadata)
  end
end

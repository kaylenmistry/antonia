defmodule AntoniaApp.Logger.PhoenixLogger do
  @moduledoc """
  Defines and attaches event handlers to Phoenix telemetry events.
  These handlers define better structured logs with information more concise and creating less noise when logging.
  """
  require Logger

  @doc false
  def start do
    handlers = %{
      [:phoenix, :router_dispatch, :stop] => &__MODULE__.phoenix_router_dispatch_stop/4,
      [:phoenix, :channel_joined] => &__MODULE__.phoenix_channel_joined/4,
      [:phoenix, :channel_handled_in] => &__MODULE__.phoenix_channel_handled_in/4
    }

    for {key, fun} <- handlers do
      :ok = :telemetry.attach({__MODULE__, key}, key, fun, :ok)
    end
  end

  @doc "Listen for events related to phoenix requests."
  def phoenix_router_dispatch_stop(_, %{duration: duration}, metadata, _) do
    %{conn: %{method: method, status: status}, route: route} = metadata

    metadata =
      Map.merge(metadata, %{
        duration_us: convert_duration(duration),
        status: status,
        method: method
      })

    Logger.info("#{method} #{route} -> #{status}", metadata)
  end

  @doc "Listen for events related to channel join."
  def phoenix_channel_joined(_, %{duration: duration}, %{socket: socket} = metadata, _) do
    metadata =
      Map.merge(metadata, %{
        duration_us: convert_duration(duration),
        socket_topic: socket.topic
      })

    Logger.info("#{join_result(metadata.result)} #{socket.topic}", metadata)
  end

  defp join_result(:ok), do: "JOINED"
  defp join_result(:error), do: "REFUSED JOIN"

  @doc "Listen for events related to channel handling."
  def phoenix_channel_handled_in(_, %{duration: duration}, %{socket: socket} = metadata, _) do
    metadata =
      Map.merge(metadata, %{
        duration_us: convert_duration(duration),
        socket_topic: socket.topic
      })

    Logger.info(
      "HANDLED #{metadata.event} INCOMING ON #{socket.topic} (#{inspect(socket.channel)})",
      metadata
    )
  end

  defp convert_duration(duration) do
    System.convert_time_unit(duration, :native, :microsecond)
  end
end

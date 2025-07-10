defmodule AntoniaApp.Logger.EctoLogger do
  @moduledoc """
  Default Telemetry for Ecto SQL based queries.
  """
  require Logger

  @measurements_of_interest [
    :decode_time,
    :idle_time,
    :query_time,
    :queue_time,
    :total_time
  ]

  @metadata_interests [:result, :source]

  @doc """
  Start the telemetry of Ecto SQL based logger.
  """
  @spec start :: :ok
  def start do
    :ok =
      :telemetry.attach(
        :antonia_ecto,
        [:antonia, :repo, :query],
        &__MODULE__.handle_event/4,
        %{}
      )
  end

  @doc """
  Listen for events related to Ecto queries.
  """
  @spec handle_event(list(), map(), map(), map()) :: :ok
  def handle_event([:antonia, :repo, :query], measurements, metadata, _config) do
    event_measurements = select_measurements_of_interests(measurements)
    event_metadata = Map.take(metadata, @metadata_interests)
    metadata = Enum.to_list(Map.merge(event_measurements, event_metadata))

    case metadata[:result] do
      {:ok, %Postgrex.Result{} = result} ->
        metadata = Keyword.drop(metadata, [:result])
        Logger.debug("SQL Query Success", metadata ++ metadata_for(result))

      {:error, error} ->
        metadata = Keyword.drop(metadata, [:result])
        Logger.error("SQL Query Error", metadata ++ metadata_for(error))
    end
  end

  @spec metadata_for(Postgrex.Result.t() | Postgrex.Error.t()) :: list()
  defp metadata_for(%Postgrex.Result{} = result) do
    [command: result.command, num_rows: result.num_rows]
  end

  defp metadata_for(%Postgrex.Error{postgres: pg_error}) do
    [code: pg_error.code, routine: pg_error.routine, severity: pg_error.severity]
  end

  @spec select_measurements_of_interests(map()) :: map()
  defp select_measurements_of_interests(measurements) do
    Map.new(
      for {key, time} <- Map.take(measurements, @measurements_of_interest) do
        {key, System.convert_time_unit(time, :native, :microsecond)}
      end
    )
  end
end

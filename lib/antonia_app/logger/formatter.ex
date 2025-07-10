defmodule AntoniaApp.Logger.Formatter do
  @moduledoc """
  Module responsible for converting log messages into a standard format
  """

  @always_excluded [:ansi_color]

  @doc """
  Receives the description of a log and outputs a string with a formatted log

  ### Parameters
    - level: The logging level that describes how critical is this log message
    - message: An iodata with the actual log message
    - timestamp: A tuple representing the log timestamp
    - metadata: A Keyword list with additional metadata related to the log
  """
  @spec format(atom(), String.t(), tuple(), Keyword.t()) :: String.t()
  def format(level, message, _timestamp, metadata) do
    log =
      [{:level, level}, {:msg, IO.iodata_to_binary(message)} | metadata]
      |> filter_relevant_metadata()
      |> filter_non_primitive_metadata()
      |> Logfmt.encode()

    log <> "\n"
  end

  @spec filter_relevant_metadata(Keyword.t()) :: Keyword.t()
  defp filter_relevant_metadata(metadata) do
    config = get_config()

    excluded = Keyword.get(config, :exclude, []) ++ @always_excluded

    Keyword.drop(metadata, excluded)
  end

  @spec filter_non_primitive_metadata(Keyword.t()) :: Keyword.t()
  defp filter_non_primitive_metadata(metadata) do
    Enum.filter(metadata, &primitive_metadata?/1)
  end

  defp primitive_metadata?({_key, value}) do
    is_binary(value) or is_atom(value) or is_number(value)
  end

  @spec get_config :: Keyword.t()
  defp get_config do
    Application.get_env(:antonia, __MODULE__, [])
  end
end

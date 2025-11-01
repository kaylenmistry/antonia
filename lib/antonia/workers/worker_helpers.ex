defmodule Antonia.Workers.WorkerHelpers do
  @moduledoc """
  Shared helper functions for Oban workers.
  """

  require Logger

  @doc """
  Times and logs function execution. Optionally accepts labels (keyword list) to annotate logs.
  """
  @spec timed(String.t(), (-> result)) :: result when result: any()
  @spec timed(String.t(), keyword() | [{atom(), any()}], (-> result)) :: result when result: any()
  def timed(operation, fun) when is_function(fun, 0) do
    timed(operation, [], fun)
  end

  def timed(operation, labels, fun) when is_function(fun, 0) do
    metadata = [{:operation, operation} | Enum.to_list(labels)]

    Logger.info("operation=#{operation} message=starting", metadata)

    {duration_us, result} = :timer.tc(fun)

    duration_ms = div(duration_us, 1000)
    Logger.info("operation=#{operation} message=completed duration_ms=#{duration_ms}", metadata)

    result
  end
end

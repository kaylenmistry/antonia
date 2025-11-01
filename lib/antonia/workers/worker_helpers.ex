defmodule Antonia.Workers.WorkerHelpers do
  @moduledoc """
  Shared helper functions for Oban workers.
  """

  require Logger

  @doc """
  Executes a function with timing and logging.

  Takes an operation name (string) and a function to execute, then:
  - Logs the start of the operation
  - Measures execution time
  - Logs completion with duration in milliseconds

  Returns the result of the function execution.

  ## Examples

      WorkerHelpers.timed("create_monthly_reports", fn ->
        ReportService.create_monthly_reports()
      end)

  """
  @spec timed(String.t(), (-> result)) :: result when result: any()
  def timed(operation, fun) when is_binary(operation) do
    Logger.info("operation=#{operation} message=starting")

    {duration_us, result} = :timer.tc(fun)

    duration_ms = div(duration_us, 1000)
    Logger.info("operation=#{operation} message=completed duration_ms=#{duration_ms}")

    result
  end
end

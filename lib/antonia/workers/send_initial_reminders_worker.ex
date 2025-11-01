defmodule Antonia.Workers.SendInitialRemindersWorker do
  @moduledoc """
  Oban worker for sending initial monthly reminders.

  Scheduled via Oban.Plugins.Cron to run on the 1st of each month at 9 AM.
  """

  use Oban.Worker, queue: :default

  require Logger

  alias Antonia.Revenue.ReportService
  alias Antonia.Workers.WorkerHelpers

  @impl Oban.Worker
  def perform(_job) do
    case WorkerHelpers.timed("send_initial_reminders", fn ->
           ReportService.send_initial_reminders()
         end) do
      {:ok, count} ->
        Logger.info("Successfully scheduled #{count} initial reminder emails")
        :ok

      {:error, reason} ->
        Logger.error("Failed to send initial reminders: #{inspect(reason)}")
        {:error, reason}
    end
  end
end

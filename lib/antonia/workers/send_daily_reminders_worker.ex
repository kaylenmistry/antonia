defmodule Antonia.Workers.SendDailyRemindersWorker do
  @moduledoc """
  Oban worker for sending daily overdue reminders.

  Scheduled via Oban.Plugins.Cron to run daily at 10 AM.
  """

  use Oban.Worker, queue: :default

  require Logger

  alias Antonia.Revenue.ReportService
  alias Antonia.Workers.WorkerHelpers

  @impl Oban.Worker
  def perform(_job) do
    case WorkerHelpers.timed("send_daily_reminders", fn ->
           ReportService.send_daily_reminders()
         end) do
      {:ok, count} ->
        Logger.info("Successfully scheduled #{count} overdue reminder emails")
        :ok

      {:error, reason} ->
        Logger.error("Failed to send daily reminders: #{inspect(reason)}")
        {:error, reason}
    end
  end
end

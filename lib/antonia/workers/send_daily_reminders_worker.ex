defmodule Antonia.Workers.SendDailyRemindersWorker do
  @moduledoc """
  Oban worker for sending daily overdue reminders.

  Scheduled via Oban.Plugins.Cron to run daily at 10 AM.
  """

  use Oban.Worker, queue: :default

  alias Antonia.Revenue.ReportService
  alias Antonia.Workers.WorkerHelpers

  @impl Oban.Worker
  def perform(_job) do
    WorkerHelpers.timed("send_daily_reminders", fn ->
      ReportService.send_daily_reminders()
    end)
  end
end

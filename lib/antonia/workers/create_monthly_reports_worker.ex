defmodule Antonia.Workers.CreateMonthlyReportsWorker do
  @moduledoc """
  Oban worker for creating monthly reports.

  Scheduled via Oban.Plugins.Cron to run on the 1st of each month at 8 AM.
  """

  use Oban.Worker, queue: :default

  alias Antonia.Revenue.ReportService
  alias Antonia.Workers.WorkerHelpers

  @impl Oban.Worker
  def perform(_job) do
    WorkerHelpers.timed("create_monthly_reports", fn ->
      ReportService.create_monthly_reports()
    end)
  end
end

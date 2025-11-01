defmodule Antonia.MailerWorker do
  @moduledoc """
  Oban worker for sending different types of emails.

  Handles:
  - Monthly reminder emails
  - Overdue reminder emails
  - Submission receipt emails
  """

  use Oban.Worker, queue: :mailers

  require Logger

  alias Antonia.Mailer.Notifier
  alias Antonia.Revenue.Report
  alias Antonia.Workers.WorkerHelpers

  alias Antonia.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"report_id" => report_id, "email_type" => email_type}}) do
    WorkerHelpers.timed("send_email", [report_id: report_id, email_type: email_type], fn ->
      with {:ok, report} <- get_report_with_store(report_id),
           {:ok, _email} <- send_email(email_type, report.store, report) do
        :ok
      else
        error ->
          Logger.error(
            "operation=send_email message=error_sending_email report_id=#{report_id} email_type=#{email_type} error=#{inspect(error)}"
          )

          {:error, error}
      end
    end)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.error("operation=send_email message=unknown_job_type args=#{inspect(args)}")
    {:error, :unknown_job_type}
  end

  # Private functions

  defp get_report_with_store(report_id) do
    case Repo.preload(Repo.get(Report, report_id), :store) do
      nil -> {:error, :report_not_found}
      report -> {:ok, report}
    end
  end

  defp send_email("monthly_reminder", store, report) do
    Notifier.deliver_monthly_reminder(store, report)
  end

  defp send_email("overdue_reminder", store, report) do
    Notifier.deliver_overdue_reminder(store, report)
  end

  defp send_email("submission_receipt", store, report) do
    Notifier.deliver_submission_receipt(store, report)
  end

  defp send_email(email_type, _store, _report) do
    {:error, "Unknown email type: #{email_type}"}
  end
end

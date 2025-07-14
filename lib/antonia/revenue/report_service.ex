defmodule Antonia.Revenue.ReportService do
  @moduledoc """
  Service for managing revenue reports and their email notifications.
  """

  import Ecto.Query
  require Logger

  alias Antonia.MailerWorker
  alias Antonia.Repo
  alias Antonia.Revenue.EmailLog
  alias Antonia.Revenue.Report
  alias Antonia.Revenue.Store

  @doc """
  Creates monthly reports for all stores for the current month.
  Only creates reports that don't already exist (idempotent).
  """
  @spec create_monthly_reports() :: {:ok, [Report.t()]} | {:error, term()}
  def create_monthly_reports do
    create_monthly_reports(Date.utc_today())
  end

  @doc """
  Creates monthly reports for all stores for the given date's month.
  Only creates reports that don't already exist (idempotent).
  """
  @spec create_monthly_reports(Date.t()) :: {:ok, [Report.t()]} | {:error, term()}
  def create_monthly_reports(date) do
    period_start = Date.beginning_of_month(date)
    period_end = Date.end_of_month(date)

    Logger.info("Creating monthly reports for #{period_start} to #{period_end}")

    # Get all stores
    stores = Repo.all(Store)

    # Get existing reports for this period
    existing_reports =
      MapSet.new(
        Repo.all(
          from(r in Report,
            where: r.period_start == ^period_start and r.period_end == ^period_end,
            select: r.store_id
          )
        )
      )

    # Create reports for stores that don't have them
    reports_to_create =
      stores
      |> Enum.reject(&MapSet.member?(existing_reports, &1.id))
      |> Enum.map(&build_report(&1, period_start, period_end))

    case Repo.insert_all(Report, reports_to_create, returning: true) do
      {count, reports} ->
        Logger.info("Created #{count} monthly reports")
        {:ok, reports}
    end
  end

  @doc """
  Sends initial monthly reminder emails to all stores with pending reports.
  Only sends to stores that haven't received a monthly reminder for this period.
  """
  @spec send_initial_reminders() :: {:ok, integer()} | {:error, term()}
  def send_initial_reminders do
    send_initial_reminders(Date.utc_today())
  end

  @doc """
  Sends initial monthly reminder emails to all stores with pending reports for the given date's month.
  Only sends to stores that haven't received a monthly reminder for this period.
  """
  @spec send_initial_reminders(Date.t()) :: {:ok, integer()} | {:error, term()}
  def send_initial_reminders(date) do
    period_start = Date.beginning_of_month(date)
    period_end = Date.end_of_month(date)

    Logger.info("Sending initial reminders for #{period_start} to #{period_end}")

    reports_needing_reminder =
      Repo.all(
        from(r in Report,
          as: :report,
          join: s in Store,
          on: s.id == r.store_id,
          where: r.period_start == ^period_start and r.period_end == ^period_end,
          where: r.status == :pending,
          where:
            not exists(
              from(el in EmailLog,
                where:
                  el.report_id == parent_as(:report).id and el.email_type == :monthly_reminder and
                    el.status == :sent
              )
            ),
          select: r
        )
      )

    count = schedule_emails(reports_needing_reminder, :monthly_reminder)
    Logger.info("Scheduled #{count} monthly reminder emails")

    {:ok, count}
  end

  @doc """
  Sends daily reminder checks for overdue reports.
  Sends overdue reminders to reports that are past due and haven't received
  an overdue reminder in the last 3 days.
  """
  @spec send_daily_reminders() :: {:ok, integer()} | {:error, term()}
  def send_daily_reminders do
    send_daily_reminders(Date.utc_today())
  end

  @doc """
  Sends daily reminder checks for overdue reports on the given date.
  """
  @spec send_daily_reminders(Date.t()) :: {:ok, integer()} | {:error, term()}
  def send_daily_reminders(date) do
    Logger.info("Checking for overdue reports on #{date}")

    # Get reports that are overdue and need reminders
    overdue_reports =
      Repo.all(
        from(r in Report,
          as: :report,
          join: s in Store,
          on: s.id == r.store_id,
          where: r.status == :pending,
          where: r.due_date < ^date,
          where:
            not exists(
              from(el in EmailLog,
                where:
                  el.report_id == parent_as(:report).id and el.email_type == "overdue_reminder" and
                    el.status == "sent",
                where: el.sent_at >= ^DateTime.new!(Date.add(date, -3), ~T[00:00:00], "Etc/UTC")
              )
            ),
          select: r
        )
      )

    count = schedule_emails(overdue_reports, "overdue_reminder")
    Logger.info("Scheduled #{count} overdue reminder emails")

    {:ok, count}
  end

  @doc """
  Handles report submission and sends receipt email.
  """
  @spec submit_report(Report.t()) :: {:ok, Report.t()} | {:error, term()}
  def submit_report(report) do
    Repo.transaction(fn ->
      # Update report status
      changeset = Report.changeset(report, %{status: "submitted"})

      case Repo.update(changeset) do
        {:ok, updated_report} ->
          # Schedule receipt email
          schedule_emails([updated_report], "submission_receipt")
          updated_report

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Processes all reports for a given month (useful for catch-up after downtime).
  """
  @spec process_month(Date.t()) :: {:ok, map()} | {:error, term()}
  def process_month(date) do
    with {:ok, reports} <- create_monthly_reports(date),
         {:ok, initial_count} <- send_initial_reminders(date),
         {:ok, overdue_count} <- send_daily_reminders(date) do
      result = %{
        reports_created: length(reports),
        initial_reminders_sent: initial_count,
        overdue_reminders_sent: overdue_count
      }

      Logger.info("Processed month #{Date.beginning_of_month(date)}: #{inspect(result)}")
      {:ok, result}
    end
  end

  # Private functions

  defp build_report(store, period_start, period_end) do
    %{
      id: Ecto.UUID.generate(),
      store_id: store.id,
      status: :pending,
      period_start: period_start,
      period_end: period_end,
      due_date: Report.calculate_due_date(period_end),
      currency: "AUD",
      revenue: Decimal.new(0),
      inserted_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
      updated_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    }
  end

  defp schedule_emails(reports, email_type) do
    Enum.each(reports, fn report ->
      %{report_id: report.id, email_type: email_type}
      |> MailerWorker.new()
      |> Oban.insert()
    end)

    length(reports)
  end
end

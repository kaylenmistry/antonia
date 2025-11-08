defmodule Antonia.Revenue.Report do
  @moduledoc false
  use Antonia.Schema

  import Ecto.Changeset

  alias Antonia.Enums.ReportStatus
  alias Antonia.Revenue.Attachment
  alias Antonia.Revenue.EmailLog
  alias Antonia.Revenue.Store

  @fields [
    :status,
    :currency,
    :revenue,
    :period_start,
    :period_end,
    :store_id,
    :due_date,
    :note
  ]

  @required_fields [
    :status,
    :currency,
    :revenue,
    :period_start,
    :period_end,
    :store_id,
    :due_date
  ]

  typed_schema "reports" do
    field(:status, Ecto.Enum, values: ReportStatus.values())
    field(:currency, :string)
    field(:revenue, :decimal)
    field(:period_start, :date)
    field(:period_end, :date)
    field(:due_date, :date)
    field(:note, :string)

    belongs_to(:store, Store)
    has_many(:email_logs, EmailLog)
    has_many(:attachments, Attachment)

    timestamps()
  end

  @doc "Changeset for reports"
  @spec changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  def changeset(report, attrs) do
    report
    |> cast(attrs, @fields)
    |> maybe_set_due_date()
    |> validate_required(@required_fields)
    |> validate_revenue_non_negative()
    |> validate_period_dates()
    |> foreign_key_constraint(:store_id)
    |> unique_constraint([:store_id, :period_start])
  end

  defp validate_revenue_non_negative(changeset) do
    case get_field(changeset, :revenue) do
      %Decimal{} = revenue ->
        if Decimal.lt?(revenue, Decimal.new("0")) do
          add_error(changeset, :revenue, "must be greater than or equal to 0")
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  defp validate_period_dates(changeset) do
    start_date = get_field(changeset, :period_start)
    end_date = get_field(changeset, :period_end)

    if start_date && end_date && Date.compare(start_date, end_date) == :gt do
      add_error(changeset, :period_end, "must be after period start")
    else
      changeset
    end
  end

  @spec maybe_set_due_date(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp maybe_set_due_date(changeset) do
    with nil <- get_field(changeset, :due_date),
         period_end when not is_nil(period_end) <- get_field(changeset, :period_end) do
      put_change(changeset, :due_date, calculate_due_date(period_end))
    else
      _ ->
        changeset
    end
  end

  # Helper functions for business logic
  @doc "Calculate due date based on period end (7 days after period end)"
  @spec calculate_due_date(Date.t()) :: Date.t()
  def calculate_due_date(period_end) do
    Date.add(period_end, 7)
  end

  @doc "Check if report is overdue"
  @spec overdue?(__MODULE__.t()) :: boolean()
  def overdue?(%__MODULE__{due_date: due_date}) when not is_nil(due_date) do
    Date.compare(Date.utc_today(), due_date) == :gt
  end

  def overdue?(_), do: false

  @doc "Check if report needs monthly reminder"
  @spec needs_monthly_reminder?(__MODULE__.t()) :: boolean()
  def needs_monthly_reminder?(%__MODULE__{id: id, status: :pending}) do
    not EmailLog.email_sent_for_report?(id, :monthly_reminder)
  end

  def needs_monthly_reminder?(_), do: false

  @doc "Check if report needs overdue reminder"
  @spec needs_overdue_reminder?(__MODULE__.t()) :: boolean()
  def needs_overdue_reminder?(%__MODULE__{status: :pending} = report) do
    overdue?(report) && should_send_overdue_reminder?(report)
  end

  def needs_overdue_reminder?(_), do: false

  defp should_send_overdue_reminder?(%__MODULE__{id: id}) do
    case EmailLog.last_sent_email(id, :overdue_reminder) do
      nil -> true
      last_email -> days_since_last_reminder(last_email) >= 3
    end
  end

  @spec days_since_last_reminder(EmailLog.t()) :: integer()
  defp days_since_last_reminder(last_email) do
    Date.diff(Date.utc_today(), DateTime.to_date(last_email.sent_at))
  end

  @doc """
  Generates timeline events for a report.

  Returns a list of timeline events sorted chronologically (oldest first).
  Each event contains:
  - `type`: `:created`, `:updated`, or `:email`
  - `title`: Event title
  - `description`: Event description
  - `timestamp`: When the event occurred
  - `is_complete`: Whether the event is complete (always true for historical events)
  """
  @spec timeline_events(__MODULE__.t() | nil) :: [map()]
  def timeline_events(nil), do: []

  def timeline_events(report) do
    report
    |> build_report_events()
    |> add_email_events(report)
    |> sort_events_by_timestamp()
  end

  defp build_report_events(report) do
    base_events = [build_created_event(report)]

    if report_was_updated?(report) do
      base_events ++ [build_updated_event(report)]
    else
      base_events
    end
  end

  defp build_created_event(report) do
    %{
      type: :created,
      title: "Report created",
      description: "Revenue report was created",
      timestamp: report.inserted_at,
      is_complete: true
    }
  end

  defp build_updated_event(report) do
    %{
      type: :updated,
      title: "Report updated",
      description: "Revenue information was modified",
      timestamp: report.updated_at,
      is_complete: true
    }
  end

  defp report_was_updated?(report) do
    NaiveDateTime.compare(report.inserted_at, report.updated_at) != :eq
  end

  defp add_email_events(events, report) do
    if email_logs_available?(report) do
      email_events = build_email_events(report.email_logs)
      events ++ email_events
    else
      events
    end
  end

  defp email_logs_available?(report) do
    Ecto.assoc_loaded?(report.email_logs) && report.email_logs
  end

  defp build_email_events(email_logs) do
    email_logs
    |> Enum.filter(fn log -> log.status == :sent && log.sent_at end)
    |> Enum.map(&build_email_event/1)
  end

  defp build_email_event(log) do
    email_type_label = get_email_type_label(log.email_type)

    %{
      type: :email,
      title: "Email sent",
      description: "Sent \"#{email_type_label}\" to #{log.recipient_email}",
      timestamp: log.sent_at,
      is_complete: true
    }
  end

  defp get_email_type_label(:monthly_reminder), do: "Monthly reminder"
  defp get_email_type_label(:overdue_reminder), do: "Overdue reminder"
  defp get_email_type_label(:initial_request), do: "Initial request"
  defp get_email_type_label(email_type), do: to_string(email_type)

  defp sort_events_by_timestamp(events) do
    Enum.sort_by(events, &timestamp_to_unix/1, :asc)
  end

  defp timestamp_to_unix(event) do
    case event.timestamp do
      %NaiveDateTime{} = dt ->
        dt |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()

      %DateTime{} = dt ->
        DateTime.to_unix(dt)

      _ ->
        0
    end
  end
end

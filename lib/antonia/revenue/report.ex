defmodule Antonia.Revenue.Report do
  @moduledoc false
  use Antonia.Schema

  import Ecto.Changeset

  alias Antonia.Enums.ReportStatus
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
    :note,
    :email_content,
    :attachment_url
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
    field(:email_content, :string)
    field(:attachment_url, :string)

    belongs_to(:store, Store)
    has_many(:email_logs, EmailLog)

    timestamps()
  end

  @doc "Changeset for reports"
  @spec changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  def changeset(report, attrs) do
    report
    |> cast(attrs, @fields)
    |> maybe_set_due_date()
    |> validate_required(@required_fields)
    |> validate_number(:revenue, greater_than_or_equal_to: 0)
    |> validate_period_dates()
    |> foreign_key_constraint(:store_id)
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
end

defmodule Antonia.Revenue.EmailLog do
  @moduledoc """
  Schema for tracking individual emails sent for reports.

  This provides a complete audit trail of all email communications
  and enables better debugging and duplicate prevention.
  """
  use Antonia.Schema

  import Ecto.Changeset

  alias Antonia.Enums.EmailStatus
  alias Antonia.Enums.EmailType
  alias Antonia.Revenue.Report

  @fields [
    :report_id,
    :email_type,
    :recipient_email,
    :subject,
    :status,
    :sent_at,
    :error_message,
    :oban_job_id,
    :submission_token,
    :expires_at,
    :accessed_at,
    :submitted_at
  ]

  @required_fields [:report_id, :email_type, :recipient_email, :subject, :status]

  typed_schema "email_logs" do
    field(:email_type, Ecto.Enum, values: EmailType.values())
    field(:recipient_email, :string)
    field(:subject, :string)
    field(:status, Ecto.Enum, values: EmailStatus.values())
    field(:sent_at, :utc_datetime)
    field(:error_message, :string)
    field(:oban_job_id, :integer)
    field(:submission_token, :string)
    field(:expires_at, :utc_datetime)
    field(:accessed_at, :utc_datetime)
    field(:submitted_at, :utc_datetime)

    belongs_to(:report, Report)

    timestamps()
  end

  @doc "Changeset for creating email logs"
  @spec changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  def changeset(email_log, attrs) do
    email_log
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:email_type, EmailType.values())
    |> validate_inclusion(:status, EmailStatus.values())
    |> validate_format(:recipient_email, ~r/@/)
    |> foreign_key_constraint(:report_id)
  end

  @doc "Mark email as sent successfully"
  @spec mark_sent(__MODULE__.t()) :: Ecto.Changeset.t()
  def mark_sent(email_log) do
    change(email_log, %{
      status: :sent,
      sent_at: DateTime.truncate(DateTime.utc_now(), :second)
    })
  end

  @doc "Mark email as failed with error message"
  @spec mark_failed(__MODULE__.t(), String.t()) :: Ecto.Changeset.t()
  def mark_failed(email_log, error_message) do
    change(email_log, %{
      status: :failed,
      error_message: error_message
    })
  end

  @doc "Check if an email of this type has been sent for this report"
  @spec email_sent_for_report?(String.t(), atom()) :: boolean()
  def email_sent_for_report?(report_id, email_type) do
    import Ecto.Query

    Antonia.Repo.exists?(
      from(e in __MODULE__,
        where:
          e.report_id == ^report_id and
            e.email_type == ^email_type and
            e.status == :sent
      )
    )
  end

  @doc "Get the last sent email of a specific type for a report"
  @spec last_sent_email(String.t(), atom()) :: __MODULE__.t() | nil
  def last_sent_email(report_id, email_type) do
    import Ecto.Query

    Antonia.Repo.one(
      from(e in __MODULE__,
        where: e.report_id == ^report_id and e.email_type == ^email_type and e.status == :sent,
        order_by: [desc: e.sent_at],
        limit: 1
      )
    )
  end

  @doc "Get all emails for a specific report"
  @spec for_report(String.t()) :: Ecto.Query.t()
  def for_report(report_id) do
    import Ecto.Query

    from(e in __MODULE__,
      where: e.report_id == ^report_id,
      order_by: [desc: e.inserted_at]
    )
  end

  @doc "Count emails of a specific type for a report"
  @spec count_by_type(String.t(), atom()) :: integer()
  def count_by_type(report_id, email_type) do
    import Ecto.Query

    Antonia.Repo.one(
      from(e in __MODULE__,
        where: e.report_id == ^report_id and e.email_type == ^email_type,
        select: count(e.id)
      )
    )
  end

  @doc "Generate a secure submission token"
  @spec generate_submission_token() :: String.t()
  def generate_submission_token do
    Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
  end

  @doc "Calculate expiry date (1 month from now)"
  @spec calculate_expires_at() :: DateTime.t()
  def calculate_expires_at do
    DateTime.utc_now()
    |> DateTime.add(30, :day)
    |> DateTime.truncate(:second)
  end

  @doc "Find email log by submission token"
  @spec find_by_token(String.t()) :: __MODULE__.t() | nil
  def find_by_token(token) do
    import Ecto.Query

    Antonia.Repo.one(
      from(e in __MODULE__,
        where: e.submission_token == ^token,
        preload: [:report]
      )
    )
  end

  @doc "Mark email log as accessed"
  @spec mark_accessed(__MODULE__.t()) :: Ecto.Changeset.t()
  def mark_accessed(email_log) do
    change(email_log, %{
      accessed_at: DateTime.truncate(DateTime.utc_now(), :second)
    })
  end

  @doc "Mark email log as submitted"
  @spec mark_submitted(__MODULE__.t()) :: Ecto.Changeset.t()
  def mark_submitted(email_log) do
    change(email_log, %{
      submitted_at: DateTime.truncate(DateTime.utc_now(), :second)
    })
  end

  @doc "Check if token is valid (not expired and not already submitted)"
  @spec valid?(__MODULE__.t() | nil) :: boolean()
  def valid?(nil), do: false

  def valid?(email_log) do
    now = DateTime.utc_now()

    cond do
      is_nil(email_log.expires_at) -> false
      DateTime.compare(now, email_log.expires_at) == :gt -> false
      not is_nil(email_log.submitted_at) -> false
      true -> true
    end
  end
end

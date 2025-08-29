defmodule Antonia.Revenue.EmailLogTest do
  use Antonia.DataCase, async: true

  alias Antonia.Revenue.EmailLog

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      report = insert(:report)

      attrs = %{
        report_id: report.id,
        email_type: :monthly_reminder,
        recipient_email: "test@example.com",
        subject: "Test Subject",
        status: :pending
      }

      changeset = EmailLog.changeset(%EmailLog{}, attrs)

      assert changeset.valid?
      assert changeset.changes.email_type == :monthly_reminder
      assert changeset.changes.status == :pending
    end

    test "requires report_id" do
      attrs = %{
        email_type: :monthly_reminder,
        recipient_email: "test@example.com",
        subject: "Test Subject",
        status: :pending
      }

      changeset = EmailLog.changeset(%EmailLog{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).report_id
    end

    test "requires email_type" do
      report = insert(:report)

      attrs = %{
        report_id: report.id,
        recipient_email: "test@example.com",
        subject: "Test Subject",
        status: :pending
      }

      changeset = EmailLog.changeset(%EmailLog{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).email_type
    end

    test "validates email_type inclusion" do
      report = insert(:report)

      attrs = %{
        report_id: report.id,
        email_type: "invalid_type",
        recipient_email: "test@example.com",
        subject: "Test Subject",
        status: :pending
      }

      changeset = EmailLog.changeset(%EmailLog{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).email_type
    end

    test "validates status inclusion" do
      report = insert(:report)

      attrs = %{
        report_id: report.id,
        email_type: :monthly_reminder,
        recipient_email: "test@example.com",
        subject: "Test Subject",
        status: :invalid_status
      }

      changeset = EmailLog.changeset(%EmailLog{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "validates recipient_email format" do
      report = insert(:report)

      attrs = %{
        report_id: report.id,
        email_type: :monthly_reminder,
        recipient_email: "invalid_email",
        subject: "Test Subject",
        status: :pending
      }

      changeset = EmailLog.changeset(%EmailLog{}, attrs)

      refute changeset.valid?
      assert "has invalid format" in errors_on(changeset).recipient_email
    end
  end

  describe "mark_sent/1" do
    test "marks email log as sent with current timestamp" do
      email_log = insert(:email_log, status: :pending)

      changeset = EmailLog.mark_sent(email_log)

      assert changeset.changes.status == :sent
      assert changeset.changes.sent_at
      assert DateTime.diff(changeset.changes.sent_at, DateTime.utc_now(), :second) < 2
    end
  end

  describe "mark_failed/2" do
    test "marks email log as failed with error message" do
      email_log = insert(:email_log, status: :pending)
      error_message = "SMTP connection failed"

      changeset = EmailLog.mark_failed(email_log, error_message)

      assert changeset.changes.status == :failed
      assert changeset.changes.error_message == error_message
    end
  end

  describe "email_sent_for_report?/2" do
    test "returns true when email of type was sent for report" do
      report = insert(:report)
      insert(:email_log, report: report, email_type: :monthly_reminder, status: :sent)

      assert EmailLog.email_sent_for_report?(report.id, :monthly_reminder)
    end

    test "returns false when email of type was not sent for report" do
      report = insert(:report)
      insert(:email_log, report: report, email_type: :monthly_reminder, status: :pending)

      refute EmailLog.email_sent_for_report?(report.id, :monthly_reminder)
    end

    test "returns false when no email log exists for report" do
      report = insert(:report)

      refute EmailLog.email_sent_for_report?(report.id, :monthly_reminder)
    end
  end

  describe "last_sent_email/2" do
    test "returns the most recent sent email of the specified type" do
      report = insert(:report)

      _older_email =
        insert(:email_log,
          report: report,
          email_type: :overdue_reminder,
          status: :sent,
          sent_at: DateTime.add(DateTime.utc_now(), -5, :day)
        )

      newer_email =
        insert(:email_log,
          report: report,
          email_type: :overdue_reminder,
          status: :sent,
          sent_at: DateTime.add(DateTime.utc_now(), -1, :day)
        )

      result = EmailLog.last_sent_email(report.id, :overdue_reminder)

      assert result.id == newer_email.id
    end

    test "returns nil when no sent emails of the type exist" do
      report = insert(:report)
      insert(:email_log, report: report, email_type: :overdue_reminder, status: :pending)

      result = EmailLog.last_sent_email(report.id, :overdue_reminder)

      assert is_nil(result)
    end
  end

  describe "for_report/1" do
    test "returns all email logs for a report" do
      report = insert(:report)
      other_report = insert(:report)

      email_log1 = insert(:email_log, report: report)
      email_log2 = insert(:email_log, report: report)
      _other_email_log = insert(:email_log, report: other_report)

      result = report.id |> EmailLog.for_report() |> Repo.all()

      assert length(result) == 2
      result_ids = Enum.map(result, & &1.id)
      assert email_log1.id in result_ids
      assert email_log2.id in result_ids
    end
  end

  describe "count_by_type/2" do
    test "returns count of emails by type for a report" do
      report = insert(:report)

      insert(:email_log, report: report, email_type: :monthly_reminder)
      insert(:email_log, report: report, email_type: :monthly_reminder)
      insert(:email_log, report: report, email_type: :overdue_reminder)

      monthly_count = EmailLog.count_by_type(report.id, :monthly_reminder)
      overdue_count = EmailLog.count_by_type(report.id, :overdue_reminder)

      assert monthly_count == 2
      assert overdue_count == 1
    end
  end
end

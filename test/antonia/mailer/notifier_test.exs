defmodule Antonia.Mailer.NotifierTest do
  use Antonia.DataCase, async: false

  import Mock

  alias Antonia.Mailer
  alias Antonia.Mailer.Notifier
  alias Antonia.Repo
  alias Antonia.Revenue.EmailLog
  alias Antonia.Revenue.Group

  describe "deliver_monthly_reminder/2" do
    test "successfully sends email and creates email log" do
      store = insert(:store, email: "test@example.com")
      report = insert(:report, store: store)

      with_mock Mailer, deliver: fn _ -> {:ok, %{}} end do
        assert {:ok, _email} = Notifier.deliver_monthly_reminder(store, report)

        # Check that email log was created
        email_log = Repo.get_by(EmailLog, report_id: report.id, email_type: :monthly_reminder)
        assert email_log
        assert email_log.recipient_email == "test@example.com"
        assert email_log.subject == "Revenue report due"
        assert email_log.status == :sent
        assert email_log.sent_at
        assert is_nil(email_log.error_message)
      end
    end

    test "creates failed email log when email delivery fails" do
      store = insert(:store, email: "test@example.com")
      report = insert(:report, store: store)

      with_mock Mailer, deliver: fn _ -> {:error, :smtp_error} end do
        assert {:error, :smtp_error} = Notifier.deliver_monthly_reminder(store, report)

        # Check that email log was created with failed status
        email_log = Repo.get_by(EmailLog, report_id: report.id, email_type: :monthly_reminder)
        assert email_log
        assert email_log.recipient_email == "test@example.com"
        assert email_log.subject == "Revenue report due"
        assert email_log.status == :failed
        assert is_nil(email_log.sent_at)
        assert email_log.error_message == ":smtp_error"
      end
    end

    test "keeps failed email log when email delivery fails" do
      store = insert(:store, email: "test@example.com")
      report = insert(:report, store: store)

      with_mock Mailer, deliver: fn _ -> {:error, :smtp_error} end do
        assert {:error, :smtp_error} = Notifier.deliver_monthly_reminder(store, report)

        # Check that failed email log is kept for audit trail
        email_log = Repo.get_by(EmailLog, report_id: report.id, email_type: :monthly_reminder)
        assert email_log
        assert email_log.status == :failed
        assert email_log.error_message == ":smtp_error"
        assert is_nil(email_log.sent_at)
      end
    end
  end

  describe "deliver_overdue_reminder/2" do
    test "successfully sends email and creates email log" do
      store = insert(:store, email: "test@example.com")
      report = insert(:report, store: store)

      with_mock Mailer, deliver: fn _ -> {:ok, %{}} end do
        assert {:ok, _email} = Notifier.deliver_overdue_reminder(store, report)

        # Check that email log was created
        email_log = Repo.get_by(EmailLog, report_id: report.id, email_type: :overdue_reminder)
        assert email_log
        assert email_log.recipient_email == "test@example.com"
        assert email_log.subject == "REMINDER: Report revenue due"
        assert email_log.status == :sent
        assert email_log.sent_at
        assert is_nil(email_log.error_message)
      end
    end

    test "creates failed email log when email delivery fails" do
      store = insert(:store, email: "test@example.com")
      report = insert(:report, store: store)

      with_mock Mailer, deliver: fn _ -> {:error, :network_timeout} end do
        assert {:error, :network_timeout} = Notifier.deliver_overdue_reminder(store, report)

        # Check that email log was created with failed status
        email_log = Repo.get_by(EmailLog, report_id: report.id, email_type: :overdue_reminder)
        assert email_log
        assert email_log.status == :failed
        assert email_log.error_message == ":network_timeout"
      end
    end
  end

  describe "deliver_submission_receipt/2" do
    test "successfully sends email and creates email log" do
      store = insert(:store, email: "test@example.com")
      report = insert(:report, store: store)

      with_mock Mailer, deliver: fn _ -> {:ok, %{}} end do
        assert {:ok, _email} = Notifier.deliver_submission_receipt(store, report)

        # Check that email log was created
        email_log = Repo.get_by(EmailLog, report_id: report.id, email_type: :submission_receipt)
        assert email_log
        assert email_log.recipient_email == "test@example.com"
        assert email_log.subject == "Thank you"
        assert email_log.status == :sent
        assert email_log.sent_at
        assert is_nil(email_log.error_message)
      end
    end

    test "creates failed email log when email delivery fails" do
      store = insert(:store, email: "test@example.com")
      report = insert(:report, store: store)

      with_mock Mailer, deliver: fn _ -> {:error, :invalid_email} end do
        assert {:error, :invalid_email} = Notifier.deliver_submission_receipt(store, report)

        # Check that email log was created with failed status
        email_log = Repo.get_by(EmailLog, report_id: report.id, email_type: :submission_receipt)
        assert email_log
        assert email_log.status == :failed
        assert email_log.error_message == ":invalid_email"
      end
    end
  end

  describe "transactional behavior" do
    test "creates email log in same transaction as email sending" do
      store = insert(:store, email: "test@example.com")
      report = insert(:report, store: store)

      # Mock Mailer.deliver to succeed
      with_mock Mailer, deliver: fn _ -> {:ok, %{}} end do
        assert {:ok, _email} = Notifier.deliver_monthly_reminder(store, report)

        # Verify email log was created in the same transaction
        email_log = Repo.get_by(EmailLog, report_id: report.id, email_type: :monthly_reminder)
        assert email_log
        assert email_log.status == :sent
      end
    end

    test "handles EmailLog validation errors" do
      store = insert(:store, email: "invalid-email")
      report = insert(:report, store: store)

      # This should fail due to invalid email format in EmailLog validation
      assert {:error, changeset} = Notifier.deliver_monthly_reminder(store, report)
      assert changeset.errors[:recipient_email]
    end
  end

  describe "email content" do
    test "monthly reminder includes correct subject and recipient" do
      store = insert(:store, email: "store@example.com")
      report = insert(:report, store: store)
      # Reload to get group association
      report = Repo.preload(report, store: [building: :group])
      group_name = report.store.building.group.name

      with_mock Mailer,
        deliver: fn email ->
          # Assert email properties
          assert email.to == [{"", "store@example.com"}]
          assert email.subject == "Revenue report due"
          assert email.from == {group_name, "notifications@revenue-report.com"}
          {:ok, %{}}
        end do
        assert {:ok, _} = Notifier.deliver_monthly_reminder(store, report)
      end
    end

    test "overdue reminder includes correct subject and recipient" do
      store = insert(:store, email: "store@example.com")
      report = insert(:report, store: store)
      # Reload to get group association
      report = Repo.preload(report, store: [building: :group])
      group_name = report.store.building.group.name

      with_mock Mailer,
        deliver: fn email ->
          # Assert email properties
          assert email.to == [{"", "store@example.com"}]
          assert email.subject == "REMINDER: Report revenue due"
          assert email.from == {group_name, "notifications@revenue-report.com"}
          {:ok, %{}}
        end do
        assert {:ok, _} = Notifier.deliver_overdue_reminder(store, report)
      end
    end

    test "submission receipt includes correct subject and recipient" do
      store = insert(:store, email: "store@example.com")
      report = insert(:report, store: store)
      # Reload to get group association
      report = Repo.preload(report, store: [building: :group])
      group_name = report.store.building.group.name

      with_mock Mailer,
        deliver: fn email ->
          # Assert email properties
          assert email.to == [{"", "store@example.com"}]
          assert email.subject == "Thank you"
          assert email.from == {group_name, "notifications@revenue-report.com"}
          {:ok, %{}}
        end do
        assert {:ok, _} = Notifier.deliver_submission_receipt(store, report)
      end
    end

    test "uses custom company name when set" do
      store = insert(:store, email: "store@example.com")
      report = insert(:report, store: store)
      # Reload to get group association
      report = Repo.preload(report, store: [building: :group])
      group = report.store.building.group
      # Update group with custom company name
      group
      |> Group.changeset(%{email_company_name: "Custom Company"})
      |> Repo.update!()

      # Reload report from database to ensure fresh associations
      report =
        Antonia.Revenue.Report
        |> Repo.get!(report.id)
        |> Repo.preload(store: [building: :group])

      with_mock Mailer,
        deliver: fn email ->
          assert email.from == {"Custom Company", "notifications@revenue-report.com"}
          {:ok, %{}}
        end do
        assert {:ok, _} = Notifier.deliver_monthly_reminder(store, report)
      end
    end
  end
end

defmodule Antonia.MailerWorkerTest do
  use Antonia.DataCase, async: true
  use Oban.Testing, repo: Antonia.Repo

  import Mock

  alias Antonia.Mailer.Notifier
  alias Antonia.MailerWorker

  describe "perform/1" do
    test "successfully processes monthly reminder email" do
      store = insert(:store)
      report = insert(:report, store: store)

      job = %Oban.Job{
        args: %{
          "report_id" => report.id,
          "email_type" => "monthly_reminder"
        }
      }

      with_mock Notifier, deliver_monthly_reminder: fn _, _, _ -> {:ok, %{}} end do
        assert :ok = MailerWorker.perform(job)
        assert_called(Notifier.deliver_monthly_reminder(:_, :_, :_))
      end
    end

    test "successfully processes overdue reminder email" do
      store = insert(:store)
      report = insert(:report, store: store)

      job = %Oban.Job{
        args: %{
          "report_id" => report.id,
          "email_type" => "overdue_reminder"
        }
      }

      with_mock Notifier, deliver_overdue_reminder: fn _, _, _ -> {:ok, %{}} end do
        assert :ok = MailerWorker.perform(job)
        assert_called(Notifier.deliver_overdue_reminder(:_, :_, :_))
      end
    end

    test "successfully processes submission receipt email" do
      store = insert(:store)
      report = insert(:report, store: store)

      job = %Oban.Job{
        args: %{
          "report_id" => report.id,
          "email_type" => "submission_receipt"
        }
      }

      with_mock Notifier, deliver_submission_receipt: fn _, _, _ -> {:ok, %{}} end do
        assert :ok = MailerWorker.perform(job)
        assert_called(Notifier.deliver_submission_receipt(:_, :_, :_))
      end
    end

    @tag :capture_log
    test "returns error when report is not found" do
      job = %Oban.Job{
        args: %{
          "report_id" => Ecto.UUID.generate(),
          "email_type" => "monthly_reminder"
        }
      }

      assert {:error, {:error, :report_not_found}} = MailerWorker.perform(job)
    end

    @tag :capture_log
    test "returns error when email type is unknown" do
      store = insert(:store)
      report = insert(:report, store: store)

      job = %Oban.Job{
        args: %{
          "report_id" => report.id,
          "email_type" => "unknown_type"
        }
      }

      assert {:error, {:error, "Unknown email type: unknown_type"}} = MailerWorker.perform(job)
    end

    @tag :capture_log
    test "returns error when notifier fails" do
      store = insert(:store)
      report = insert(:report, store: store)

      job = %Oban.Job{
        args: %{
          "report_id" => report.id,
          "email_type" => "monthly_reminder"
        }
      }

      with_mock Notifier, deliver_monthly_reminder: fn _, _, _ -> {:error, :smtp_error} end do
        assert {:error, {:error, :smtp_error}} = MailerWorker.perform(job)
      end
    end

    @tag :capture_log
    test "returns error for unknown job arguments" do
      job = %Oban.Job{
        args: %{
          "unknown_key" => "unknown_value"
        }
      }

      assert {:error, :unknown_job_type} = MailerWorker.perform(job)
    end

    test "handles missing store preload gracefully" do
      # Create report without preloading store
      report = insert(:report)

      job = %Oban.Job{
        args: %{
          "report_id" => report.id,
          "email_type" => "monthly_reminder"
        }
      }

      with_mock Notifier, deliver_monthly_reminder: fn _, _, _ -> {:ok, %{}} end do
        assert :ok = MailerWorker.perform(job)
        # The worker should handle preloading the store
        assert_called(Notifier.deliver_monthly_reminder(:_, :_, :_))
      end
    end
  end

  describe "integration with Oban" do
    test "can be enqueued and processed" do
      store = insert(:store)
      report = insert(:report, store: store)

      job = %{
        "report_id" => report.id,
        "email_type" => "monthly_reminder"
      }

      with_mock Notifier, deliver_monthly_reminder: fn _, _, _ -> {:ok, %{}} end do
        assert {:ok, _} = job |> MailerWorker.new() |> Oban.insert()

        # Process the job
        perform_job(MailerWorker, job)

        assert_called(Notifier.deliver_monthly_reminder(:_, :_, :_))
      end
    end
  end
end

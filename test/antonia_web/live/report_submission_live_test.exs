defmodule AntoniaWeb.ReportSubmissionLiveTest do
  use AntoniaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Antonia.Repo
  alias Antonia.Revenue.EmailLog
  alias Antonia.Revenue.Report

  describe "mount/3" do
    test "renders form for valid token", %{conn: conn} do
      report = insert(:report)
      token = EmailLog.generate_submission_token()

      insert(:email_log,
        report: report,
        submission_token: token,
        expires_at: DateTime.add(DateTime.utc_now(), 1, :day),
        status: :sent
      )

      {:ok, view, _html} = live(conn, ~p"/submit/#{token}")

      assert has_element?(view, "h1", "Revenue Report Submission")
      assert has_element?(view, "form")
      assert render(view) =~ report.store.name
    end

    test "shows error for non-existent token", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/submit/non-existent-token")

      assert has_element?(view, "h1", "Invalid Link")
      assert render(view) =~ "not valid or has been removed"
    end

    test "shows error for expired token", %{conn: conn} do
      report = insert(:report)
      token = EmailLog.generate_submission_token()

      insert(:email_log,
        report: report,
        submission_token: token,
        expires_at: DateTime.add(DateTime.utc_now(), -1, :day),
        status: :sent
      )

      {:ok, view, _html} = live(conn, ~p"/submit/#{token}")

      assert has_element?(view, "h1", "Link Expired")
      assert render(view) =~ "expired"
    end

    test "shows error for already submitted token", %{conn: conn} do
      report = insert(:report)
      token = EmailLog.generate_submission_token()

      insert(:email_log,
        report: report,
        submission_token: token,
        expires_at: DateTime.add(DateTime.utc_now(), 1, :day),
        submitted_at: DateTime.utc_now(),
        status: :sent
      )

      {:ok, view, _html} = live(conn, ~p"/submit/#{token}")

      assert has_element?(view, "h1", "Link Expired")
      assert render(view) =~ "already been submitted"
    end

    test "marks token as accessed on first visit", %{conn: conn} do
      report = insert(:report)
      token = EmailLog.generate_submission_token()

      email_log =
        insert(:email_log,
          report: report,
          submission_token: token,
          expires_at: DateTime.add(DateTime.utc_now(), 1, :day),
          accessed_at: nil,
          status: :sent
        )

      assert is_nil(email_log.accessed_at)

      {:ok, _view, _html} = live(conn, ~p"/submit/#{token}")

      updated_log = Repo.get!(EmailLog, email_log.id)
      assert updated_log.accessed_at
    end
  end

  describe "submit_report" do
    test "successfully submits report and shows thank you", %{conn: conn} do
      report = insert(:report, revenue: Decimal.new("1000.00"), note: nil)
      token = EmailLog.generate_submission_token()

      email_log =
        insert(:email_log,
          report: report,
          submission_token: token,
          expires_at: DateTime.add(DateTime.utc_now(), 1, :day),
          status: :sent
        )

      {:ok, view, _html} = live(conn, ~p"/submit/#{token}")

      # Submit the form
      view
      |> form("form", %{revenue: "1500.50", note: "Test note"})
      |> render_submit()

      # Verify report was updated in database (this confirms the submission worked)
      updated_report = Repo.get!(Report, report.id)
      assert Decimal.equal?(updated_report.revenue, Decimal.new("1500.50"))
      assert updated_report.note == "Test note"

      # Verify email log was marked as submitted
      updated_log = Repo.get!(EmailLog, email_log.id)
      assert updated_log.submitted_at
      assert DateTime.compare(updated_log.expires_at, email_log.expires_at) == :gt

      # The view should show thank you message after successful submission
      # Re-render to get the updated state
      html = render(view)
      assert html =~ "Thank You!" or html =~ "submitted successfully"
    end

    test "extends expiry by 30 minutes after submission", %{conn: conn} do
      report = insert(:report)
      token = EmailLog.generate_submission_token()
      original_expires_at = DateTime.add(DateTime.utc_now(), 1, :day)

      email_log =
        insert(:email_log,
          report: report,
          submission_token: token,
          expires_at: original_expires_at,
          status: :sent
        )

      {:ok, view, _html} = live(conn, ~p"/submit/#{token}")

      view
      |> form("form", %{revenue: "1000.00"})
      |> render_submit()

      updated_log = Repo.get!(EmailLog, email_log.id)
      minutes_diff = DateTime.diff(updated_log.expires_at, original_expires_at, :minute)
      assert minutes_diff >= 29
      assert minutes_diff <= 31
    end

    test "shows error for invalid revenue", %{conn: conn} do
      report = insert(:report, revenue: Decimal.new("1000.00"))
      token = EmailLog.generate_submission_token()

      email_log =
        insert(:email_log,
          report: report,
          submission_token: token,
          expires_at: DateTime.add(DateTime.utc_now(), 1, :day),
          status: :sent
        )

      {:ok, view, _html} = live(conn, ~p"/submit/#{token}")

      # Submit form with negative revenue
      view
      |> form("form", %{revenue: "-100"})
      |> render_submit()

      # Check that form is still visible (not showing thank you message)
      refute has_element?(view, "h1", "Thank You!")

      # Verify report was NOT updated - revenue should still be the original value
      updated_report = Repo.get!(Report, report.id)
      assert Decimal.equal?(updated_report.revenue, report.revenue)

      # Verify email log was NOT marked as submitted
      updated_log = Repo.get!(EmailLog, email_log.id)
      assert is_nil(updated_log.submitted_at)
    end
  end

  describe "update_revenue" do
    test "updates revenue value in real-time", %{conn: conn} do
      report = insert(:report)
      token = EmailLog.generate_submission_token()

      insert(:email_log,
        report: report,
        submission_token: token,
        expires_at: DateTime.add(DateTime.utc_now(), 1, :day),
        status: :sent
      )

      {:ok, view, _html} = live(conn, ~p"/submit/#{token}")

      assert view
             |> element("form")
             |> render_change(%{revenue: "2500.75"}) =~ "2500.75"
    end
  end
end

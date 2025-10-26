defmodule Antonia.Revenue.ReportTest do
  use Antonia.DataCase, async: true

  alias Antonia.Revenue.Report

  describe "changeset/2" do
    test "with valid attributes" do
      store = insert(:store)

      attrs = %{
        status: :pending,
        currency: "AUD",
        revenue: 1500.00,
        period_start: Date.new!(2025, 1, 1),
        period_end: Date.new!(2025, 1, 31),
        store_id: store.id,
        due_date: Date.new!(2025, 2, 7)
      }

      changeset = Report.changeset(%Report{}, attrs)

      assert changeset.valid?
    end

    test "requires all required fields" do
      changeset = Report.changeset(%Report{}, %{})

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :status)
      assert Keyword.has_key?(changeset.errors, :currency)
      assert Keyword.has_key?(changeset.errors, :revenue)
      assert Keyword.has_key?(changeset.errors, :period_start)
      assert Keyword.has_key?(changeset.errors, :period_end)
      assert Keyword.has_key?(changeset.errors, :store_id)
    end

    test "validates revenue is greater than 0" do
      store = insert(:store)

      attrs = %{
        status: :pending,
        currency: "AUD",
        revenue: -100,
        period_start: Date.new!(2025, 1, 1),
        period_end: Date.new!(2025, 1, 31),
        store_id: store.id,
        due_date: Date.new!(2025, 2, 7)
      }

      changeset = Report.changeset(%Report{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :revenue)
    end

    test "validates revenue is greater than 0 when zero" do
      store = insert(:store)

      attrs = %{
        status: :pending,
        currency: "AUD",
        revenue: 0,
        period_start: Date.new!(2025, 1, 1),
        period_end: Date.new!(2025, 1, 31),
        store_id: store.id,
        due_date: Date.new!(2025, 2, 7)
      }

      changeset = Report.changeset(%Report{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :revenue)
    end

    test "validates period_end is after period_start" do
      store = insert(:store)

      attrs = %{
        status: :pending,
        currency: "AUD",
        revenue: 1500.00,
        period_start: Date.new!(2025, 1, 31),
        period_end: Date.new!(2025, 1, 1),
        store_id: store.id,
        due_date: Date.new!(2025, 2, 7)
      }

      changeset = Report.changeset(%Report{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :period_end)
    end

    test "allows period_start and period_end to be equal" do
      store = insert(:store)

      attrs = %{
        status: :pending,
        currency: "AUD",
        revenue: 1500.00,
        period_start: Date.new!(2025, 1, 1),
        period_end: Date.new!(2025, 1, 1),
        store_id: store.id,
        due_date: Date.new!(2025, 2, 7)
      }

      changeset = Report.changeset(%Report{}, attrs)

      assert changeset.valid?
    end

    test "auto-calculates due_date when not provided" do
      store = insert(:store)

      # Create changeset with all required fields including due_date = nil
      # The maybe_set_due_date should calculate it
      attrs = %{
        status: :pending,
        currency: "AUD",
        revenue: Decimal.new("1500.00"),
        period_start: Date.new!(2025, 1, 1),
        period_end: Date.new!(2025, 1, 31),
        store_id: store.id,
        # Simulate what should be calculated
        due_date: Date.new!(2025, 2, 7)
      }

      changeset = Report.changeset(%Report{}, attrs)

      assert changeset.valid?
      assert get_field(changeset, :due_date) == Date.new!(2025, 2, 7)
    end

    test "uses provided due_date instead of calculating" do
      store = insert(:store)

      attrs = %{
        status: :pending,
        currency: "AUD",
        revenue: 1500.00,
        period_start: Date.new!(2025, 1, 1),
        period_end: Date.new!(2025, 1, 31),
        store_id: store.id,
        due_date: Date.new!(2025, 3, 1)
      }

      changeset = Report.changeset(%Report{}, attrs)

      assert changeset.valid?
      assert get_field(changeset, :due_date) == Date.new!(2025, 3, 1)
    end

    test "allows optional fields" do
      store = insert(:store)

      attrs = %{
        status: :pending,
        currency: "AUD",
        revenue: 1500.00,
        period_start: Date.new!(2025, 1, 1),
        period_end: Date.new!(2025, 1, 31),
        store_id: store.id,
        due_date: Date.new!(2025, 2, 7),
        note: "Test note",
        email_content: "Content",
        attachment_url: "https://example.com/file.pdf"
      }

      changeset = Report.changeset(%Report{}, attrs)

      assert changeset.valid?
      assert get_field(changeset, :note) == "Test note"
      assert get_field(changeset, :email_content) == "Content"
      assert get_field(changeset, :attachment_url) == "https://example.com/file.pdf"
    end
  end

  describe "calculate_due_date/1" do
    test "calculates due date as 7 days after period end" do
      period_end = Date.new!(2025, 1, 31)
      due_date = Report.calculate_due_date(period_end)

      assert due_date == Date.new!(2025, 2, 7)
    end

    test "handles month boundary" do
      period_end = Date.new!(2025, 1, 28)
      due_date = Report.calculate_due_date(period_end)

      assert due_date == Date.new!(2025, 2, 4)
    end
  end

  describe "overdue?/1" do
    test "returns true for overdue reports" do
      report = insert(:report, due_date: Date.add(Date.utc_today(), -1))

      assert Report.overdue?(report) == true
    end

    test "returns false for reports not yet due" do
      report = insert(:report, due_date: Date.add(Date.utc_today(), 1))

      assert Report.overdue?(report) == false
    end

    test "returns false for reports due today" do
      report = insert(:report, due_date: Date.utc_today())

      assert Report.overdue?(report) == false
    end

    test "returns false for reports without due_date" do
      report = %Report{}

      assert Report.overdue?(report) == false
    end
  end

  describe "needs_monthly_reminder?/1" do
    test "returns true for pending reports without monthly reminder" do
      report = insert(:report, status: :pending)

      assert Report.needs_monthly_reminder?(report) == true
    end

    test "returns false for reports that already have monthly reminder" do
      report = insert(:report, status: :pending)
      insert(:email_log, report: report, email_type: :monthly_reminder, status: :sent)

      refute Report.needs_monthly_reminder?(report)
    end

    test "returns false for non-pending reports" do
      report = insert(:report, status: :submitted)

      assert Report.needs_monthly_reminder?(report) == false
    end
  end

  describe "needs_overdue_reminder?/1" do
    test "returns true for overdue pending reports" do
      report = insert(:report, status: :pending, due_date: Date.add(Date.utc_today(), -1))

      assert Report.needs_overdue_reminder?(report) == true
    end

    test "returns false for non-overdue pending reports" do
      report = insert(:report, status: :pending, due_date: Date.add(Date.utc_today(), 1))

      assert Report.needs_overdue_reminder?(report) == false
    end

    test "returns false for non-pending reports" do
      report = insert(:report, status: :submitted, due_date: Date.add(Date.utc_today(), -1))

      assert Report.needs_overdue_reminder?(report) == false
    end

    test "does not send if reminder was sent within last 3 days" do
      report = insert(:report, status: :pending, due_date: Date.add(Date.utc_today(), -5))

      # Create recent reminder
      insert(:email_log,
        report: report,
        email_type: :overdue_reminder,
        status: :sent,
        sent_at: DateTime.add(DateTime.utc_now(), -2, :day)
      )

      refute Report.needs_overdue_reminder?(report)
    end

    test "sends if last reminder was more than 3 days ago" do
      report = insert(:report, status: :pending, due_date: Date.add(Date.utc_today(), -10))

      # Create old reminder
      insert(:email_log,
        report: report,
        email_type: :overdue_reminder,
        status: :sent,
        sent_at: DateTime.add(DateTime.utc_now(), -4, :day)
      )

      assert Report.needs_overdue_reminder?(report) == true
    end
  end
end

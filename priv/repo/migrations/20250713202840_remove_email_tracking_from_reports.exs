defmodule Antonia.Repo.Migrations.RemoveEmailTrackingFromReports do
  use Ecto.Migration

  def change do
    # Remove indexes first
    drop index(:reports, [:monthly_reminder_sent_at])
    drop index(:reports, [:overdue_reminder_sent_at])

    # Remove the email tracking fields
    alter table(:reports) do
      remove :monthly_reminder_sent_at
      remove :overdue_reminder_sent_at
      remove :submission_receipt_sent_at
    end
  end
end

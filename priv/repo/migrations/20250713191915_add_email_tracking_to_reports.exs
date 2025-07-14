defmodule Antonia.Repo.Migrations.AddEmailTrackingToReports do
  use Ecto.Migration

  def change do
    alter table(:reports) do
      add :monthly_reminder_sent_at, :utc_datetime
      add :overdue_reminder_sent_at, :utc_datetime
      add :submission_receipt_sent_at, :utc_datetime
      add :due_date, :date
    end

    create index(:reports, [:due_date])
    create index(:reports, [:monthly_reminder_sent_at])
    create index(:reports, [:overdue_reminder_sent_at])
  end
end

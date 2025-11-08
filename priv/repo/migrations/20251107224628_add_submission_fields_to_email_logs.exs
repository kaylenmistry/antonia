defmodule Antonia.Repo.Migrations.AddSubmissionFieldsToEmailLogs do
  use Ecto.Migration

  def change do
    alter table(:email_logs) do
      add :submission_token, :string
      add :expires_at, :utc_datetime
      add :accessed_at, :utc_datetime
      add :submitted_at, :utc_datetime
    end

    create unique_index(:email_logs, [:submission_token])
  end
end

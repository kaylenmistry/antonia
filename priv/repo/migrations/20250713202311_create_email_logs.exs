defmodule Antonia.Repo.Migrations.CreateEmailLogs do
  use Ecto.Migration

  def change do
    create table(:email_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :report_id, references(:reports, on_delete: :delete_all, type: :binary_id), null: false
      add :email_type, :string, null: false
      add :recipient_email, :string, null: false
      add :subject, :string, null: false
      add :status, :string, null: false
      add :sent_at, :utc_datetime
      add :error_message, :text
      add :oban_job_id, :integer

      timestamps(type: :utc_datetime)
    end
  end
end

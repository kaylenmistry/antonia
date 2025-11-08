defmodule Antonia.Repo.Migrations.CreateAttachments do
  use Ecto.Migration

  def change do
    create table(:attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :s3_key, :string, null: false
      add :filename, :string, null: false
      add :file_type, :string, null: false
      add :file_size, :integer
      add :metadata, :jsonb

      add :report_id, references(:reports, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:attachments, [:report_id])
    create index(:attachments, [:s3_key])
  end
end

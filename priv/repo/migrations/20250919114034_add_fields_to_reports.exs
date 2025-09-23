defmodule Antonia.Repo.Migrations.AddFieldsToReports do
  use Ecto.Migration

  def change do
    alter table(:reports) do
      add :note, :text
      add :email_content, :text
      add :attachment_url, :string
    end
  end
end

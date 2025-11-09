defmodule Antonia.Repo.Migrations.RemoveUnusedFieldsFromReports do
  use Ecto.Migration

  def change do
    alter table(:reports) do
      remove :email_content
      remove :attachment_url
    end
  end
end


defmodule Antonia.Repo.Migrations.AddEmailConfigToGroups do
  use Ecto.Migration

  def change do
    alter table(:groups) do
      add :email_logo_url, :string
      add :email_company_name, :string
    end
  end
end

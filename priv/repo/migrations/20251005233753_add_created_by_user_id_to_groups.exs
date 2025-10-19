defmodule Antonia.Repo.Migrations.AddCreatedByUserIdToGroups do
  use Ecto.Migration

  def change do
    alter table(:groups) do
      add :created_by_user_id, references(:users, on_delete: :delete_all, type: :uuid),
        null: false
    end

    create index(:groups, [:created_by_user_id])
  end
end

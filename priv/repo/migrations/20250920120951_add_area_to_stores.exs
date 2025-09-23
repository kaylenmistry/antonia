defmodule Antonia.Repo.Migrations.AddAreaToStores do
  use Ecto.Migration

  def change do
    alter table(:stores) do
      add :area, :integer, null: false
    end
  end
end

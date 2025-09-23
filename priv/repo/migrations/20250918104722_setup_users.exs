defmodule Antonia.Repo.Migrations.SetupUsers do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create_if_not_exists table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :uid, :string, null: false
      add :provider, :string, null: false
      add :email, :citext, null: false
      add :first_name, :string
      add :last_name, :string
      add :location, :string
      add :image, :string

      timestamps()
    end
  end
end

defmodule Antonia.Repo.Migrations.SetupBasicSchema do
  use Ecto.Migration

  def change do
    # Create groups table
    create table(:groups, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create table(:buildings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :address, :text
      add :group_id, references(:groups, on_delete: :nilify_all, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create table(:stores, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :email, :string, null: false

      add :building_id,
          references(:buildings, on_delete: :delete_all, type: :binary_id),
          null: false

      timestamps()
    end

    create table(:reports, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false
      add :currency, :string, null: false
      add :revenue, :decimal, precision: 15, scale: 2, null: false
      add :period_start, :date, null: false
      add :period_end, :date, null: false
      add :store_id, references(:stores, on_delete: :delete_all, type: :binary_id), null: false
      add :due_date, :date, null: false

      timestamps()
    end

    create unique_index(:reports, [:store_id, :period_start])

    create index(:buildings, [:group_id])
    create index(:stores, [:building_id])
    create index(:reports, [:store_id])
    create index(:reports, [:store_id, :status])
  end
end

defmodule Antonia.Repo.Migrations.SetupBasicSchema do
  use Ecto.Migration

  def change do
    create table(:shopping_centres, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create table(:stores, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :email, :string, null: false

      add :shopping_centre_id,
          references(:shopping_centres, on_delete: :delete_all, type: :binary_id),
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

    create index(:stores, [:shopping_centre_id])
    create index(:reports, [:store_id])
    create index(:reports, [:store_id, :status])
  end
end

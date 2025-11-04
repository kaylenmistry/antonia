defmodule Antonia.Repo.Migrations.AddDefaultCurrencyToGroups do
  use Ecto.Migration

  def change do
    alter table(:groups) do
      add :default_currency, :string, default: "EUR", null: false
    end
  end
end

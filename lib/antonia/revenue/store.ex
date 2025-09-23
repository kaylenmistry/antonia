defmodule Antonia.Revenue.Store do
  @moduledoc false
  use Antonia.Schema

  import Ecto.Changeset

  alias Antonia.Revenue.Building
  alias Antonia.Revenue.Report

  @fields [
    :name,
    :email,
    :building_id,
    :area
  ]

  @required_fields @fields

  typed_schema "stores" do
    field(:name, :string)
    field(:email, :string)
    field(:area, :integer)

    belongs_to(:building, Building)
    has_many(:reports, Report)

    timestamps()
  end

  @doc "Changeset for stores"
  @spec changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  def changeset(store, attrs) do
    store
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_format(:email, ~r/@/)
    |> foreign_key_constraint(:building_id)
  end
end

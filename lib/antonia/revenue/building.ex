defmodule Antonia.Revenue.Building do
  @moduledoc false
  use Antonia.Schema

  import Ecto.Changeset

  alias Antonia.Revenue.Group
  alias Antonia.Revenue.Store

  @fields [
    :name,
    :address,
    :group_id
  ]

  @required_fields [:name]

  typed_schema "buildings" do
    field(:name, :string)
    field(:address, :string)

    belongs_to(:group, Group)
    has_many(:stores, Store)

    timestamps()
  end

  @doc "Changeset for buildings"
  @spec changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  def changeset(building, attrs) do
    building
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> foreign_key_constraint(:group_id)
  end
end

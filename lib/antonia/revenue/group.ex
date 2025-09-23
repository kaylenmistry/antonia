defmodule Antonia.Revenue.Group do
  @moduledoc false
  use Antonia.Schema

  import Ecto.Changeset

  alias Antonia.Revenue.Building

  @fields [
    :name
  ]

  @required_fields [:name]

  typed_schema "groups" do
    field(:name, :string)

    has_many(:buildings, Building)

    timestamps()
  end

  @doc "Changeset for groups"
  @spec changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  def changeset(group, attrs) do
    group
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
  end
end

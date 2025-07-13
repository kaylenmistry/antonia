defmodule Antonia.Revenue.ShoppingCentre do
  @moduledoc false
  use Antonia.Schema

  import Ecto.Changeset

  alias Antonia.Revenue.Store

  @fields [
    :name
  ]

  @required_fields @fields

  typed_schema "shopping_centres" do
    field(:name, :string)

    has_many(:stores, Store)

    timestamps()
  end

  @doc "Changeset for shopping centres"
  @spec changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  def changeset(shopping_centre, attrs) do
    shopping_centre
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end
end

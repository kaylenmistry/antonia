defmodule Antonia.Revenue.Store do
  @moduledoc false
  use Antonia.Schema

  import Ecto.Changeset

  alias Antonia.Revenue.Report
  alias Antonia.Revenue.ShoppingCentre

  @fields [
    :name,
    :email,
    :shopping_centre_id
  ]

  @required_fields @fields

  typed_schema "stores" do
    field(:name, :string)
    field(:email, :string)

    belongs_to(:shopping_centre, ShoppingCentre)
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
    |> foreign_key_constraint(:shopping_centre_id)
  end
end

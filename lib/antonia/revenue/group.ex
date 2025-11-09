defmodule Antonia.Revenue.Group do
  @moduledoc false
  use Antonia.Schema

  import Ecto.Changeset

  alias Antonia.Revenue.Building

  @fields [
    :name,
    :created_by_user_id,
    :default_currency
  ]

  @required_fields [:name]

  typed_schema "groups" do
    field(:name, :string)
    field(:default_currency, :string, default: "EUR")

    belongs_to(:created_by_user, Antonia.Accounts.User)
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
    |> put_default_currency()
    |> foreign_key_constraint(:created_by_user_id)
  end

  @doc "Changeset for groups with action (for Backpex compatibility)"
  @spec changeset(__MODULE__.t(), map(), atom()) :: Ecto.Changeset.t()
  def changeset(group, attrs, _action) do
    changeset(group, attrs)
  end

  defp put_default_currency(changeset) do
    case get_field(changeset, :default_currency) do
      nil -> put_change(changeset, :default_currency, "EUR")
      _ -> changeset
    end
  end
end

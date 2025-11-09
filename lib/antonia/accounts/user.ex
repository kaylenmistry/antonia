defmodule Antonia.Accounts.User do
  @moduledoc false
  use Antonia.Schema

  import Ecto.Changeset

  alias Antonia.Accounts.User
  alias Antonia.Enums.AuthProvider

  @fields [
    :uid,
    :provider,
    :email,
    :first_name,
    :last_name,
    :location,
    :image
  ]

  @required_fields [
    :uid,
    :provider,
    :email
  ]

  @timestamps_opts [type: :utc_datetime]

  typed_schema "users" do
    field(:uid, :string)
    field(:provider, Ecto.Enum, values: AuthProvider.values())
    field(:email, :string)
    field(:first_name, :string)
    field(:last_name, :string)
    field(:location, :string)
    field(:image, :string)

    timestamps()
  end

  @doc "Changeset for users"
  @spec changeset(User.t(), map()) :: Ecto.Changeset.t()
  def changeset(user, attrs) do
    user
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_email()
  end

  @doc "Changeset for users with action (for Backpex compatibility)"
  @spec changeset(User.t(), map(), atom()) :: Ecto.Changeset.t()
  def changeset(user, attrs, _action) do
    changeset(user, attrs)
  end

  @spec validate_email(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Antonia.Repo)
    |> unique_constraint(:email)
  end

  @doc "Returns the full name of a user"
  @spec full_name(User.t()) :: String.t()
  def full_name(%User{first_name: first_name, last_name: last_name}) do
    [first_name, last_name]
    |> Enum.filter(&(not is_nil(&1)))
    |> Enum.join(" ")
  end
end

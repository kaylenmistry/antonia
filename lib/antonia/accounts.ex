defmodule Antonia.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false

  require Logger

  alias Antonia.Accounts.User
  alias Antonia.Repo

  ##### User #####

  @doc "Fetches user by email. Returns nil if no user is found."
  @spec get_user_by_email(binary()) :: User.t() | nil
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_email(_email), do: nil

  @doc "Gets a user by ID. Returns nil if no user is found."
  @spec get_user(binary()) :: User.t() | nil
  def get_user(id) do
    Repo.get(User, id)
  end

  @doc "Gets a user's custom prompt. Returns nil if no user is found."
  @spec get_user_custom_prompt(binary()) :: String.t() | nil
  def get_user_custom_prompt(user_id) do
    case get_user(user_id) do
      nil -> nil
      user -> user.custom_prompt
    end
  end

  # Creates a new user with a default personal account.
  @spec create_new_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  defp create_new_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Creates a new user, or updates an existing one if a user with the same email already exists."
  @spec create_or_update_user(map()) :: {:ok, User.t()} | {:error, atom()}
  def create_or_update_user(%{email: email} = attrs) do
    case get_user_by_email(email) do
      nil -> create_new_user(attrs)
      existing_user -> update_user(existing_user, attrs)
    end
  end

  def create_or_update_user(_attrs), do: {:error, :missing_email_attribute}

  @doc "Updates a user with the given attributes."
  @spec update_user(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end
end

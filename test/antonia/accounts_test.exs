defmodule Antonia.AccountsTest do
  use Antonia.DataCase, async: true

  alias Antonia.Accounts
  alias Antonia.Accounts.User

  @valid_attrs %{
    email: "test@example.com",
    uid: "123",
    provider: :kinde
  }

  describe "get_user_by_email/1" do
    test "returns the user if it exists" do
      user = insert(:user)

      assert user == Accounts.get_user_by_email(user.email)
    end

    test "returns nil if the user does not exist" do
      assert nil == Accounts.get_user_by_email("nonexistent@example.com")
    end

    test "returns nil if email is not a binary" do
      assert nil == Accounts.get_user_by_email(nil)
      assert nil == Accounts.get_user_by_email(123)
      assert nil == Accounts.get_user_by_email(%{})
    end
  end

  describe "get_user/1" do
    test "returns the user if it exists" do
      user = insert(:user)

      assert user == Accounts.get_user(user.id)
    end

    test "returns nil if the user does not exist" do
      non_existent_id = Uniq.UUID.uuid7()
      assert nil == Accounts.get_user(non_existent_id)
    end
  end

  describe "create_or_update_user/1" do
    test "creates a user if one does not exist" do
      {:ok, user} = Accounts.create_or_update_user(@valid_attrs)
      assert user.id
      assert user.email == "test@example.com"
      assert user.uid == "123"
      assert user.provider == :kinde
    end

    test "updates a user if one already exists" do
      user = insert(:user, email: "test@example.com")
      {:ok, fetched_user} = Accounts.create_or_update_user(@valid_attrs)

      assert user.id == fetched_user.id
      assert user.email == fetched_user.email
      # Assert that the uid was updated
      assert @valid_attrs.uid == fetched_user.uid
    end

    test "returns {:error, :missing_email_attribute} if the email attribute is missing" do
      assert {:error, :missing_email_attribute} == Accounts.create_or_update_user(%{})
    end
  end

  describe "update_user/2" do
    test "updates the user" do
      user = insert(:user)

      assert {:ok, %User{first_name: "New", last_name: "Name"}} =
               Accounts.update_user(user, %{first_name: "New", last_name: "Name"})
    end

    test "returns changeset error if the changeset is invalid" do
      user = insert(:user)

      assert {:error,
              %Ecto.Changeset{
                errors: [email: {"must have the @ sign and no spaces", [validation: :format]}]
              }} = Accounts.update_user(user, %{email: "invalid"})
    end
  end

  describe "change_user/1" do
    test "returns a changeset for a new user" do
      changeset = Accounts.change_user()
      assert changeset.valid? == false
      assert changeset.data.__struct__ == User
    end

    test "returns a changeset for an existing user" do
      user = insert(:user)
      changeset = Accounts.change_user(user)
      assert changeset.valid? == true
      assert changeset.data == user
    end
  end
end

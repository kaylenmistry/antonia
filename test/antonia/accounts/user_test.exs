defmodule Antonia.Accounts.UserTest do
  use Antonia.DataCase, async: true

  alias Antonia.Accounts.User

  describe "changeset/2" do
    test "with valid attributes" do
      attrs = %{
        uid: "123",
        provider: :kinde,
        email: "test@example.com",
        first_name: "John",
        last_name: "Doe"
      }

      changeset = User.changeset(%User{}, attrs)

      assert changeset.valid?
    end

    test "requires required fields" do
      changeset = User.changeset(%User{}, %{})

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :uid)
      assert Keyword.has_key?(changeset.errors, :provider)
      assert Keyword.has_key?(changeset.errors, :email)
    end

    test "validates email format" do
      attrs = %{
        uid: "123",
        provider: :kinde,
        email: "invalid-email"
      }

      changeset = User.changeset(%User{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :email)
    end

    test "validates email has @ sign" do
      attrs = %{
        uid: "123",
        provider: :kinde,
        email: "noatsign"
      }

      changeset = User.changeset(%User{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :email)
    end

    test "validates email has no spaces" do
      attrs = %{
        uid: "123",
        provider: :kinde,
        email: "test @example.com"
      }

      changeset = User.changeset(%User{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :email)
    end

    test "validates email max length" do
      attrs = %{
        uid: "123",
        provider: :kinde,
        email: String.duplicate("a", 200) <> "@example.com"
      }

      changeset = User.changeset(%User{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :email)
    end

    test "accepts optional fields" do
      attrs = %{
        uid: "123",
        provider: :kinde,
        email: "test@example.com",
        location: "San Francisco",
        image: "https://example.com/avatar.jpg"
      }

      changeset = User.changeset(%User{}, attrs)

      assert changeset.valid?
    end
  end

  describe "full_name/1" do
    test "returns full name when both first and last name exist" do
      user = %User{first_name: "John", last_name: "Doe"}

      assert User.full_name(user) == "John Doe"
    end

    test "returns only first name when last name is nil" do
      user = %User{first_name: "John", last_name: nil}

      assert User.full_name(user) == "John"
    end

    test "returns only last name when first name is nil" do
      user = %User{first_name: nil, last_name: "Doe"}

      assert User.full_name(user) == "Doe"
    end

    test "returns empty string when both names are nil" do
      user = %User{first_name: nil, last_name: nil}

      assert User.full_name(user) == ""
    end

    test "handles multiple spaces correctly" do
      user = %User{first_name: "John  ", last_name: "  Doe"}

      assert User.full_name(user) == "John     Doe"
    end
  end
end

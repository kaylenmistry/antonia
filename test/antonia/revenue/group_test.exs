defmodule Antonia.Revenue.GroupTest do
  use Antonia.DataCase

  alias Antonia.Revenue

  describe "update_group/3" do
    test "updates group name" do
      user = insert(:user)
      group = insert(:group, created_by_user: user, name: "Original Name")

      attrs = %{name: "Updated Name"}

      assert {:ok, updated_group} = Revenue.update_group(user.id, group.id, attrs)
      assert updated_group.name == "Updated Name"
    end

    test "updates email configuration" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)

      attrs = %{
        email_company_name: "Custom Company",
        email_logo_url: "https://example.com/logo.png"
      }

      assert {:ok, updated_group} = Revenue.update_group(user.id, group.id, attrs)
      assert updated_group.email_company_name == "Custom Company"
      assert updated_group.email_logo_url == "https://example.com/logo.png"
    end

    test "returns error when user doesn't own group" do
      user = insert(:user)
      other_user = insert(:user)
      group = insert(:group, created_by_user: other_user)

      assert {:error, :group_not_found} =
               Revenue.update_group(user.id, group.id, %{name: "New Name"})
    end

    test "returns error when group not found" do
      user = insert(:user)
      fake_id = Uniq.UUID.uuid7()

      assert {:error, :group_not_found} =
               Revenue.update_group(user.id, fake_id, %{name: "New Name"})
    end

    test "validates required fields" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)

      assert {:error, changeset} = Revenue.update_group(user.id, group.id, %{name: ""})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end
  end
end

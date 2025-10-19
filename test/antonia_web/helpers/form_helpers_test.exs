defmodule AntoniaWeb.FormHelpersTest do
  use ExUnit.Case, async: true

  alias AntoniaWeb.FormHelpers

  describe "format_params/1" do
    test "handles empty list" do
      assert FormHelpers.format_params([]) == []
    end

    test "handles empty map" do
      assert FormHelpers.format_params(%{}) == %{}
    end

    test "ignores non-existent atom keys" do
      assert FormHelpers.format_params(%{"non_existent_atom" => "foo"}) == %{}
    end

    test "converts string keys to existing atoms" do
      assert FormHelpers.format_params(%{"name" => "foo"}) == %{name: "foo"}
    end

    test "handles nested maps" do
      assert FormHelpers.format_params(%{"group" => %{"name" => "foo"}}) == %{
               group: %{name: "foo"}
             }
    end

    test "handles lists of maps" do
      assert FormHelpers.format_params(%{"items" => [%{"name" => "item1"}]}) == %{
               items: [%{name: "item1"}]
             }
    end

    test "preserves atom keys" do
      assert FormHelpers.format_params(%{name: "foo"}) == %{name: "foo"}
    end

    test "handles lists with atom keys" do
      assert FormHelpers.format_params([%{name: "foo"}]) == [%{name: "foo"}]
    end

    test "handles mixed valid and invalid keys" do
      params = %{
        "name" => "valid",
        "nonexistent_field" => "ignored",
        "created_by_user_id" => "user123"
      }

      expected = %{
        name: "valid",
        created_by_user_id: "user123"
      }

      assert FormHelpers.format_params(params) == expected
    end

    test "handles deeply nested structures" do
      params = %{
        "group" => %{
          "name" => "Test Group",
          "nonexistent_field" => "ignored",
          "buildings" => [
            %{"name" => "Building 1", "nonexistent" => "ignored"},
            %{"name" => "Building 2"}
          ]
        }
      }

      expected = %{
        group: %{
          name: "Test Group",
          buildings: [
            %{name: "Building 1"},
            %{name: "Building 2"}
          ]
        }
      }

      assert FormHelpers.format_params(params) == expected
    end

    test "handles nil values" do
      assert FormHelpers.format_params(%{"name" => nil}) == %{name: nil}
    end

    test "handles boolean values" do
      assert FormHelpers.format_params(%{"active" => true}) == %{active: true}
    end

    test "handles numeric values" do
      assert FormHelpers.format_params(%{"count" => 42}) == %{count: 42}
    end
  end
end

defmodule Antonia.RevenueTest do
  use Antonia.DataCase, async: true

  alias Antonia.Revenue
  alias Antonia.Revenue.Building
  alias Antonia.Revenue.Group
  alias Antonia.Revenue.Report
  alias Antonia.Revenue.Store

  describe "list_groups/1" do
    test "returns groups ordered alphabetically by name" do
      user = insert(:user)
      insert(:group, created_by_user_id: user.id, name: "Charlie Group")
      insert(:group, created_by_user_id: user.id, name: "Alpha Group")
      insert(:group, created_by_user_id: user.id, name: "Beta Group")

      groups = Revenue.list_groups(user.id)
      assert Enum.map(groups, & &1.name) == ["Alpha Group", "Beta Group", "Charlie Group"]
    end

    test "returns empty list when no groups exist" do
      user = insert(:user)
      assert [] == Revenue.list_groups(user.id)
    end
  end

  describe "get_group/2" do
    test "returns group when it exists" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)

      assert {:ok, %Group{id: group_id}} = Revenue.get_group(user.id, group.id)
      assert group_id == group.id
    end

    test "returns error when group does not exist" do
      user = insert(:user)
      non_existent_id = Uniq.UUID.uuid7()

      assert {:error, :group_not_found} = Revenue.get_group(user.id, non_existent_id)
    end
  end

  describe "create_group/2" do
    test "creates a group with valid data" do
      user = insert(:user)
      attrs = %{name: "New Group"}

      assert {:ok, %Group{name: "New Group"}} = Revenue.create_group(user.id, attrs)
    end

    test "returns error with invalid data" do
      user = insert(:user)
      attrs = %{}

      assert {:error, changeset} = Revenue.create_group(user.id, attrs)
      refute changeset.valid?
      assert {"can't be blank", [validation: :required]} = changeset.errors[:name]
    end
  end

  describe "list_buildings/2" do
    test "returns buildings ordered alphabetically by name" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      insert(:building, group: group, name: "Charlie Building")
      insert(:building, group: group, name: "Alpha Building")
      insert(:building, group: group, name: "Beta Building")

      buildings = Revenue.list_buildings(user.id, group.id)

      assert Enum.map(buildings, & &1.name) == [
               "Alpha Building",
               "Beta Building",
               "Charlie Building"
             ]
    end

    test "returns empty list when group has no buildings" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)

      assert [] == Revenue.list_buildings(user.id, group.id)
    end

    test "returns empty list for non-existent group" do
      user = insert(:user)
      non_existent_id = Uniq.UUID.uuid7()

      assert [] == Revenue.list_buildings(user.id, non_existent_id)
    end
  end

  describe "get_building/3" do
    test "returns building when it exists and belongs to group" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      building = insert(:building, group: group)

      assert %Building{id: building_id} = Revenue.get_building(user.id, group.id, building.id)
      assert building_id == building.id
    end

    test "returns nil when building exists but belongs to different group" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      other_group = insert(:group)
      building = insert(:building, group: other_group)

      assert nil == Revenue.get_building(user.id, group.id, building.id)
    end

    test "returns nil when building does not exist" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      non_existent_id = Uniq.UUID.uuid7()

      assert nil == Revenue.get_building(user.id, group.id, non_existent_id)
    end
  end

  describe "create_building/3" do
    test "creates a building with valid data" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      attrs = %{name: "New Building", address: "123 Test St"}

      assert {:ok, %Building{name: "New Building", address: "123 Test St"}} =
               Revenue.create_building(user.id, group.id, attrs)
    end

    test "returns error with invalid data" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      attrs = %{}

      assert {:error, changeset} = Revenue.create_building(user.id, group.id, attrs)
      refute changeset.valid?
      assert {"can't be blank", [validation: :required]} = changeset.errors[:name]
    end
  end

  describe "list_stores/3" do
    test "returns stores ordered alphabetically by name" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      building = insert(:building, group: group)
      insert(:store, building: building, name: "Charlie Store")
      insert(:store, building: building, name: "Alpha Store")
      insert(:store, building: building, name: "Beta Store")

      stores = Revenue.list_stores(user.id, group.id, building.id)
      assert Enum.map(stores, & &1.name) == ["Alpha Store", "Beta Store", "Charlie Store"]
    end

    test "returns empty list when building has no stores" do
      user = insert(:user)
      group = insert(:group)
      building = insert(:building, group: group)

      assert [] == Revenue.list_stores(user.id, group.id, building.id)
    end

    test "returns empty list for non-existent building" do
      user = insert(:user)
      group = insert(:group)
      non_existent_id = Uniq.UUID.uuid7()

      assert [] == Revenue.list_stores(user.id, group.id, non_existent_id)
    end
  end

  describe "get_store/4" do
    test "returns store when it exists and belongs to building" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      building = insert(:building, group: group)
      store = insert(:store, building: building)

      assert %Store{id: store_id} = Revenue.get_store(user.id, group.id, building.id, store.id)
      assert store_id == store.id
    end

    test "returns nil when store exists but belongs to different building" do
      user = insert(:user)
      group = insert(:group)
      building = insert(:building, group: group)
      other_building = insert(:building, group: group)
      store = insert(:store, building: other_building)

      assert nil == Revenue.get_store(user.id, group.id, building.id, store.id)
    end

    test "returns nil when store does not exist" do
      user = insert(:user)
      group = insert(:group)
      building = insert(:building, group: group)
      non_existent_id = Uniq.UUID.uuid7()

      assert nil == Revenue.get_store(user.id, group.id, building.id, non_existent_id)
    end
  end

  describe "create_store/4" do
    test "creates a store with valid data" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      building = insert(:building, group: group)
      attrs = %{name: "New Store", email: "store@example.com", area: 100}

      assert {:ok, %Store{name: "New Store", email: "store@example.com", area: 100}} =
               Revenue.create_store(user.id, group.id, building.id, attrs)
    end

    test "returns error with invalid data" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      building = insert(:building, group: group)
      attrs = %{}

      assert {:error, changeset} = Revenue.create_store(user.id, group.id, building.id, attrs)
      refute changeset.valid?
      assert {"can't be blank", [validation: :required]} = changeset.errors[:name]
    end
  end

  describe "list_reports/4" do
    test "returns all reports for a store" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      building = insert(:building, group: group)
      store = insert(:store, building: building)
      report1 = insert(:report, store: store)
      report2 = insert(:report, store: store)
      # Create a report for a different store
      other_store = insert(:store, building: building)
      _other_report = insert(:report, store: other_store)

      reports = Revenue.list_reports(user.id, group.id, building.id, store.id)
      assert length(reports) == 2
      # Order by inserted_at desc (newest first) - check that we have both reports
      report_ids = Enum.map(reports, & &1.id)
      assert report1.id in report_ids
      assert report2.id in report_ids
    end

    test "returns empty list when store has no reports" do
      user = insert(:user)
      group = insert(:group)
      building = insert(:building, group: group)
      store = insert(:store, building: building)

      assert [] == Revenue.list_reports(user.id, group.id, building.id, store.id)
    end

    test "returns empty list for non-existent store" do
      user = insert(:user)
      group = insert(:group)
      building = insert(:building, group: group)
      non_existent_id = Uniq.UUID.uuid7()

      assert [] == Revenue.list_reports(user.id, group.id, building.id, non_existent_id)
    end
  end

  describe "get_report/5" do
    test "returns report when it exists and belongs to store" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      building = insert(:building, group: group)
      store = insert(:store, building: building)
      report = insert(:report, store: store)

      assert {:ok, %Report{id: report_id}} =
               Revenue.get_report(user.id, group.id, building.id, store.id, report.id)

      assert report_id == report.id
    end

    test "returns error when report exists but belongs to different store" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      building = insert(:building, group: group)
      store = insert(:store, building: building)
      other_store = insert(:store, building: building)
      report = insert(:report, store: other_store)

      assert {:error, :report_not_found} =
               Revenue.get_report(user.id, group.id, building.id, store.id, report.id)
    end

    test "returns error when report does not exist" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      building = insert(:building, group: group)
      store = insert(:store, building: building)
      non_existent_id = Uniq.UUID.uuid7()

      assert {:error, :report_not_found} =
               Revenue.get_report(user.id, group.id, building.id, store.id, non_existent_id)
    end
  end

  describe "create_report/5" do
    test "creates a report with valid data" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      building = insert(:building, group: group)
      store = insert(:store, building: building)

      attrs = %{
        status: :pending,
        currency: "AUD",
        revenue: 1500.00,
        period_start: Date.new!(2025, 2, 1),
        period_end: Date.new!(2025, 2, 28),
        due_date: Date.new!(2025, 3, 7)
      }

      assert {:ok, %Report{status: :pending, currency: "AUD"}} =
               Revenue.create_report(user.id, group.id, building.id, store.id, attrs)
    end

    test "returns error with invalid data" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      building = insert(:building, group: group)
      store = insert(:store, building: building)
      attrs = %{}

      assert {:error, changeset} =
               Revenue.create_report(user.id, group.id, building.id, store.id, attrs)

      refute changeset.valid?
      assert {"can't be blank", [validation: :required]} = changeset.errors[:status]
    end
  end

  describe "update_report/6" do
    test "updates report with valid data" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      building = insert(:building, group: group)
      store = insert(:store, building: building)
      report = insert(:report, store: store)
      attrs = %{status: :submitted, note: "Updated report"}

      assert {:ok, %Report{status: :submitted, note: "Updated report"}} =
               Revenue.update_report(user.id, group.id, building.id, store.id, report.id, attrs)
    end

    test "returns error when report does not exist" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      building = insert(:building, group: group)
      store = insert(:store, building: building)
      non_existent_id = Uniq.UUID.uuid7()
      attrs = %{status: :submitted}

      assert {:error, :report_not_found} =
               Revenue.update_report(
                 user.id,
                 group.id,
                 building.id,
                 store.id,
                 non_existent_id,
                 attrs
               )
    end

    test "returns error with invalid data" do
      user = insert(:user)
      group = insert(:group, created_by_user_id: user.id)
      building = insert(:building, group: group)
      store = insert(:store, building: building)
      report = insert(:report, store: store)
      attrs = %{status: :invalid_status}

      assert {:error, changeset} =
               Revenue.update_report(user.id, group.id, building.id, store.id, report.id, attrs)

      refute changeset.valid?
    end
  end

  describe "business logic helpers" do
    test "find_report_for_period/3 finds correct report" do
      report1 =
        insert(:report, period_start: Date.new!(2025, 1, 1), period_end: Date.new!(2025, 1, 31))

      report2 =
        insert(:report, period_start: Date.new!(2025, 2, 1), period_end: Date.new!(2025, 2, 28))

      reports = [report1, report2]

      assert Revenue.find_report_for_period(reports, 2025, 1) == report1
      assert Revenue.find_report_for_period(reports, 2025, 2) == report2
      assert Revenue.find_report_for_period(reports, 2025, 3) == nil
    end

    test "calculate_store_area/1 returns area when set" do
      store = %Store{area: 150}
      assert Revenue.calculate_store_area(store) == 150
    end

    test "calculate_store_area/1 returns 0 when area is nil" do
      store = %Store{area: nil}
      assert Revenue.calculate_store_area(store) == 0
    end

    test "calculate_due_date/1 adds 7 days to period end" do
      period_end = Date.new!(2025, 1, 31)
      expected_due_date = Date.new!(2025, 2, 7)
      assert Revenue.calculate_due_date(period_end) == expected_due_date
    end

    test "valid_store_access?/3 returns true for valid hierarchy" do
      group = insert(:group)
      building = insert(:building, group: group)
      store = insert(:store, building: building)

      assert Revenue.valid_store_access?(group, building, store) == true
    end

    test "valid_store_access?/3 returns false for invalid hierarchy" do
      group1 = insert(:group)
      group2 = insert(:group)
      building = insert(:building, group: group1)
      store = insert(:store, building: building)

      # Different group
      assert Revenue.valid_store_access?(group2, building, store) == false

      # Different building
      other_building = insert(:building, group: group1)
      assert Revenue.valid_store_access?(group1, other_building, store) == false
    end

    test "generate_historical_data/3 generates 12 months of data" do
      store = :store |> insert() |> Repo.preload(:reports)
      historical_data = Revenue.generate_historical_data(store, 6, 2025)

      assert length(historical_data) == 12
      assert Enum.all?(historical_data, &is_map/1)

      assert Enum.all?(historical_data, fn data ->
               Map.has_key?(data, :year) and Map.has_key?(data, :month) and
                 Map.has_key?(data, :revenue)
             end)
    end
  end
end

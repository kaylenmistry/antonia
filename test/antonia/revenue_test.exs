defmodule Antonia.RevenueTest do
  use Antonia.DataCase, async: true

  alias Antonia.Revenue

  ############################
  # Groups Tests
  ############################

  describe "list_groups/1" do
    test "lists all groups for a user" do
      user = insert(:user)
      _group1 = insert(:group, name: "AAA Group", created_by_user: user)
      _group2 = insert(:group, name: "BBB Group", created_by_user: user)
      # Different user's group
      _other_group = insert(:group, name: "Other Group")

      groups = Revenue.list_groups(user.id)

      assert length(groups) == 2
      assert Enum.all?(groups, fn g -> g.created_by_user_id == user.id end)
    end

    test "returns empty list for user with no groups" do
      user = insert(:user)

      assert Revenue.list_groups(user.id) == []
    end

    test "orders groups alphabetically" do
      user = insert(:user)
      _ = insert(:group, name: "Zebra Group", created_by_user: user)
      _ = insert(:group, name: "Alpha Group", created_by_user: user)

      groups = Revenue.list_groups(user.id)

      assert [first, second] = groups
      assert first.name == "Alpha Group"
      assert second.name == "Zebra Group"
    end
  end

  describe "list_groups_with_stats/1" do
    test "returns groups with stats for a user" do
      user = insert(:user)
      group = insert(:group, name: "Test Group", created_by_user: user)
      building1 = insert(:building, group: group)
      building2 = insert(:building, group: group)
      _store1 = insert(:store, building: building1)
      _store2 = insert(:store, building: building1)
      _store3 = insert(:store, building: building2)

      groups = Revenue.list_groups_with_stats(user.id)

      assert length(groups) == 1
      assert [group_with_stats] = groups
      assert group_with_stats.id == group.id
      assert group_with_stats.name == "Test Group"
      assert %{stats: stats} = group_with_stats
      assert stats.buildings_count == 2
      assert stats.stores_count == 3
      assert stats.pending_reports_count == 3
    end

    test "calculates pending reports correctly - no reports means all pending" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      building = insert(:building, group: group)
      insert(:store, building: building)
      insert(:store, building: building)

      [group_with_stats] = Revenue.list_groups_with_stats(user.id)

      assert group_with_stats.stats.pending_reports_count == 2
      assert group_with_stats.stats.stores_count == 2
    end

    test "calculates pending reports correctly - submitted reports reduce pending count" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      building = insert(:building, group: group)
      store1 = insert(:store, building: building)
      store2 = insert(:store, building: building)
      store3 = insert(:store, building: building)

      current_month = Date.beginning_of_month(Date.utc_today())
      period_end = Date.end_of_month(current_month)

      # Store 1 has submitted report
      insert(:report,
        store: store1,
        status: :submitted,
        period_start: current_month,
        period_end: period_end
      )

      # Store 2 has approved report
      insert(:report,
        store: store2,
        status: :approved,
        period_start: current_month,
        period_end: period_end
      )

      # Store 3 has pending report (doesn't count as completed)
      insert(:report,
        store: store3,
        status: :pending,
        period_start: current_month,
        period_end: period_end
      )

      [group_with_stats] = Revenue.list_groups_with_stats(user.id)

      assert group_with_stats.stats.stores_count == 3
      assert group_with_stats.stats.pending_reports_count == 1
    end

    test "ignores reports from previous months when calculating pending" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      building = insert(:building, group: group)
      store = insert(:store, building: building)

      previous_month_date = Date.beginning_of_month(Date.utc_today())
      previous_month = previous_month_date |> Date.add(-32) |> Date.beginning_of_month()

      previous_month_end = Date.end_of_month(previous_month)

      # Has report for previous month, but not current month
      insert(:report,
        store: store,
        status: :submitted,
        period_start: previous_month,
        period_end: previous_month_end
      )

      [group_with_stats] = Revenue.list_groups_with_stats(user.id)

      assert group_with_stats.stats.stores_count == 1
      assert group_with_stats.stats.pending_reports_count == 1
    end

    test "returns empty stats for groups with no buildings or stores" do
      user = insert(:user)
      _group = insert(:group, created_by_user: user)

      [group_with_stats] = Revenue.list_groups_with_stats(user.id)

      assert group_with_stats.stats.buildings_count == 0
      assert group_with_stats.stats.stores_count == 0
      assert group_with_stats.stats.pending_reports_count == 0
    end

    test "only returns groups for the specified user" do
      user = insert(:user)
      other_user = insert(:user)
      group1 = insert(:group, created_by_user: user)
      _group2 = insert(:group, created_by_user: other_user)

      groups = Revenue.list_groups_with_stats(user.id)

      assert length(groups) == 1
      assert hd(groups).id == group1.id
    end

    test "orders groups alphabetically" do
      user = insert(:user)
      _group1 = insert(:group, name: "Zebra Group", created_by_user: user)
      _group2 = insert(:group, name: "Alpha Group", created_by_user: user)

      groups = Revenue.list_groups_with_stats(user.id)

      assert [first, second] = groups
      assert first.name == "Alpha Group"
      assert second.name == "Zebra Group"
    end

    test "returns empty list for user with no groups" do
      user = insert(:user)

      assert Revenue.list_groups_with_stats(user.id) == []
    end

    test "handles stores across multiple buildings correctly" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      building1 = insert(:building, group: group)
      building2 = insert(:building, group: group)
      insert(:store, building: building1)
      insert(:store, building: building2)

      [group_with_stats] = Revenue.list_groups_with_stats(user.id)

      assert group_with_stats.stats.buildings_count == 2
      assert group_with_stats.stats.stores_count == 2
      assert group_with_stats.stats.pending_reports_count == 2
    end
  end

  describe "get_group/2" do
    test "returns group when user owns it" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)

      assert {:ok, fetched_group} = Revenue.get_group(user.id, group.id)
      assert fetched_group.id == group.id
    end

    test "returns error when group not found" do
      user = insert(:user)
      other_user = insert(:user)
      group = insert(:group, created_by_user: other_user)

      assert {:error, :group_not_found} = Revenue.get_group(user.id, group.id)
    end

    test "returns error when group doesn't exist" do
      user = insert(:user)
      fake_id = Uniq.UUID.uuid7()

      assert {:error, :group_not_found} = Revenue.get_group(user.id, fake_id)
    end
  end

  describe "create_group/2" do
    test "creates a new group" do
      user = insert(:user)

      assert {:ok, group} = Revenue.create_group(user.id, %{name: "New Group"})
      assert group.name == "New Group"
      assert group.created_by_user_id == user.id
    end

    test "returns error when name is missing" do
      user = insert(:user)

      assert {:error, changeset} = Revenue.create_group(user.id, %{})
      refute changeset.valid?
    end

    test "sets created_by_user_id from user_id parameter" do
      user = insert(:user)

      {:ok, group} = Revenue.create_group(user.id, %{name: "Test"})

      assert group.created_by_user_id == user.id
    end
  end

  describe "change_group/1" do
    test "returns changeset for new group" do
      changeset = Revenue.change_group()

      assert changeset.data.__struct__ == Revenue.Group
      refute changeset.valid?
    end

    test "returns changeset for existing group" do
      group = insert(:group)

      changeset = Revenue.change_group(group)

      assert changeset.valid?
      assert changeset.data == group
    end
  end

  ############################
  # Buildings Tests
  ############################

  describe "list_buildings/2" do
    test "lists buildings for a group" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      building1 = insert(:building, name: "Building A", group: group)
      building2 = insert(:building, name: "Building B", group: group)

      buildings = Revenue.list_buildings(user.id, group.id)

      assert length(buildings) == 2
      building_ids = Enum.map(buildings, & &1.id)
      assert building1.id in building_ids
      assert building2.id in building_ids
    end

    test "orders buildings alphabetically" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      _building2 = insert(:building, name: "Zebra", group: group)
      _building1 = insert(:building, name: "Alpha", group: group)

      buildings = Revenue.list_buildings(user.id, group.id)

      assert [first, second] = buildings
      assert first.name == "Alpha"
      assert second.name == "Zebra"
    end

    test "returns empty list when user doesn't own group" do
      user = insert(:user)
      other_user = insert(:user)
      group = insert(:group, created_by_user: other_user)
      insert(:building, group: group)

      assert Revenue.list_buildings(user.id, group.id) == []
    end

    test "returns empty list when group doesn't exist" do
      user = insert(:user)
      fake_id = Uniq.UUID.uuid7()

      assert Revenue.list_buildings(user.id, fake_id) == []
    end
  end

  describe "get_building/3" do
    test "returns building when user has access" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      building = insert(:building, group: group)

      fetched_building = Revenue.get_building(user.id, group.id, building.id)

      assert fetched_building.id == building.id
    end

    test "returns nil when user doesn't own group" do
      user = insert(:user)
      other_user = insert(:user)
      group = insert(:group, created_by_user: other_user)
      building = insert(:building, group: group)

      assert Revenue.get_building(user.id, group.id, building.id) == nil
    end

    test "returns nil when building doesn't exist" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      fake_id = Uniq.UUID.uuid7()

      assert Revenue.get_building(user.id, group.id, fake_id) == nil
    end
  end

  describe "create_building/3" do
    test "creates building for group" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)

      assert {:ok, building} = Revenue.create_building(user.id, group.id, %{name: "New Building"})
      assert building.name == "New Building"
      assert building.group_id == group.id
    end

    test "returns error when user doesn't own group" do
      user = insert(:user)
      other_user = insert(:user)
      group = insert(:group, created_by_user: other_user)

      assert {:error, :group_not_found} =
               Revenue.create_building(user.id, group.id, %{name: "New Building"})
    end

    test "returns error when group doesn't exist" do
      user = insert(:user)
      fake_id = Uniq.UUID.uuid7()

      assert {:error, :group_not_found} =
               Revenue.create_building(user.id, fake_id, %{name: "New Building"})
    end
  end

  describe "change_building/1" do
    test "returns changeset for new building" do
      changeset = Revenue.change_building()

      assert changeset.data.__struct__ == Revenue.Building
      refute changeset.valid?
    end
  end

  ############################
  # Stores Tests
  ############################

  describe "list_stores/3" do
    test "lists stores for a building" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      building = insert(:building, group: group)
      store1 = insert(:store, name: "Store A", building: building)
      store2 = insert(:store, name: "Store B", building: building)

      stores = Revenue.list_stores(user.id, group.id, building.id)

      assert length(stores) == 2
      store_ids = Enum.map(stores, & &1.id)
      assert store1.id in store_ids
      assert store2.id in store_ids
    end

    test "orders stores alphabetically" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      building = insert(:building, group: group)
      _store2 = insert(:store, name: "Zebra", building: building)
      _store1 = insert(:store, name: "Alpha", building: building)

      stores = Revenue.list_stores(user.id, group.id, building.id)

      assert [first, second] = stores
      assert first.name == "Alpha"
      assert second.name == "Zebra"
    end

    test "returns empty list when user doesn't own group" do
      user = insert(:user)
      other_user = insert(:user)
      group = insert(:group, created_by_user: other_user)
      building = insert(:building, group: group)
      insert(:store, building: building)

      assert Revenue.list_stores(user.id, group.id, building.id) == []
    end
  end

  describe "get_store/4" do
    test "returns store with preloaded reports" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      building = insert(:building, group: group)
      store = insert(:store, building: building)
      report = insert(:report, store: store)

      fetched_store = Revenue.get_store(user.id, group.id, building.id, store.id)

      assert fetched_store.id == store.id
      assert length(fetched_store.reports) == 1
      assert hd(fetched_store.reports).id == report.id
    end

    test "returns nil when user doesn't own group" do
      user = insert(:user)
      other_user = insert(:user)
      group = insert(:group, created_by_user: other_user)
      building = insert(:building, group: group)
      store = insert(:store, building: building)

      assert Revenue.get_store(user.id, group.id, building.id, store.id) == nil
    end
  end

  describe "create_store/4" do
    test "creates store for building" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      building = insert(:building, group: group)

      attrs = %{name: "New Store", email: "store@example.com", area: 100}

      assert {:ok, store} = Revenue.create_store(user.id, group.id, building.id, attrs)
      assert store.name == "New Store"
      assert store.building_id == building.id
    end

    test "returns error when user doesn't own group" do
      user = insert(:user)
      other_user = insert(:user)
      group = insert(:group, created_by_user: other_user)
      building = insert(:building, group: group)

      attrs = %{name: "New Store", email: "store@example.com", area: 100}

      assert {:error, :group_not_found} =
               Revenue.create_store(user.id, group.id, building.id, attrs)
    end
  end

  describe "change_store/1" do
    test "returns changeset for new store" do
      changeset = Revenue.change_store()

      assert changeset.data.__struct__ == Revenue.Store
      refute changeset.valid?
    end
  end

  ############################
  # Reports Tests
  ############################

  describe "list_reports/4" do
    test "lists reports for a store" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      building = insert(:building, group: group)
      store = insert(:store, building: building)
      _report1 = insert(:report, store: store)
      _report2 = insert(:report, store: store)

      reports = Revenue.list_reports(user.id, group.id, building.id, store.id)

      assert length(reports) == 2
      # Verify reports are ordered by inserted_at descending
      assert Enum.at(reports, 0).inserted_at >= Enum.at(reports, 1).inserted_at
    end

    test "returns empty list when user doesn't own group" do
      user = insert(:user)
      other_user = insert(:user)
      group = insert(:group, created_by_user: other_user)
      building = insert(:building, group: group)
      store = insert(:store, building: building)
      insert(:report, store: store)

      assert Revenue.list_reports(user.id, group.id, building.id, store.id) == []
    end
  end

  describe "get_report/5" do
    test "returns report when it exists" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      building = insert(:building, group: group)
      store = insert(:store, building: building)
      report = insert(:report, store: store)

      assert {:ok, fetched_report} =
               Revenue.get_report(user.id, group.id, building.id, store.id, report.id)

      assert fetched_report.id == report.id
    end

    test "returns error when report not found" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      building = insert(:building, group: group)
      store = insert(:store, building: building)
      fake_id = Uniq.UUID.uuid7()

      assert {:error, :report_not_found} =
               Revenue.get_report(user.id, group.id, building.id, store.id, fake_id)
    end
  end

  describe "create_report/5" do
    test "creates report for store" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      building = insert(:building, group: group)
      store = insert(:store, building: building)

      attrs = %{
        status: :pending,
        currency: "AUD",
        revenue: Decimal.new("1000.00"),
        period_start: Date.new!(2025, 1, 1),
        period_end: Date.new!(2025, 1, 31),
        due_date: Date.new!(2025, 2, 7)
      }

      assert {:ok, report} =
               Revenue.create_report(user.id, group.id, building.id, store.id, attrs)

      assert report.status == :pending
      assert report.store_id == store.id
    end

    test "returns error when user doesn't own group" do
      user = insert(:user)
      other_user = insert(:user)
      group = insert(:group, created_by_user: other_user)
      building = insert(:building, group: group)
      store = insert(:store, building: building)

      attrs = %{status: :pending, currency: "AUD", revenue: Decimal.new("1000.00")}

      assert {:error, :group_not_found} =
               Revenue.create_report(user.id, group.id, building.id, store.id, attrs)
    end
  end

  describe "update_report/6" do
    test "updates report" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      building = insert(:building, group: group)
      store = insert(:store, building: building)
      report = insert(:report, store: store, status: :pending)

      attrs = %{status: :submitted, note: "Updated note"}

      assert {:ok, updated_report} =
               Revenue.update_report(user.id, group.id, building.id, store.id, report.id, attrs)

      assert updated_report.status == :submitted
      assert updated_report.note == "Updated note"
    end

    test "returns error when user doesn't own group" do
      user = insert(:user)
      other_user = insert(:user)
      group = insert(:group, created_by_user: other_user)
      building = insert(:building, group: group)
      store = insert(:store, building: building)
      report = insert(:report, store: store)

      assert {:error, :group_not_found} =
               Revenue.update_report(user.id, group.id, building.id, store.id, report.id, %{})
    end

    test "returns error when report not found" do
      user = insert(:user)
      group = insert(:group, created_by_user: user)
      building = insert(:building, group: group)
      store = insert(:store, building: building)
      fake_id = Uniq.UUID.uuid7()

      assert {:error, :report_not_found} =
               Revenue.update_report(user.id, group.id, building.id, store.id, fake_id, %{})
    end
  end

  describe "change_report/1" do
    test "returns changeset for new report" do
      changeset = Revenue.change_report()

      assert changeset.data.__struct__ == Revenue.Report
      refute changeset.valid?
    end
  end

  ############################
  # Business Logic Helpers
  ############################

  describe "find_report_for_period/3" do
    test "finds report for specific period" do
      report1 =
        insert(:report, period_start: Date.new!(2025, 1, 1), period_end: Date.new!(2025, 1, 31))

      report2 =
        insert(:report, period_start: Date.new!(2025, 2, 1), period_end: Date.new!(2025, 2, 28))

      found = Revenue.find_report_for_period([report1, report2], 2025, 1)

      assert found.id == report1.id
    end

    test "returns nil when no report found for period" do
      report =
        insert(:report, period_start: Date.new!(2025, 1, 1), period_end: Date.new!(2025, 1, 31))

      assert Revenue.find_report_for_period([report], 2025, 3) == nil
    end

    test "handles empty list" do
      assert Revenue.find_report_for_period([], 2025, 1) == nil
    end
  end

  describe "generate_historical_data/3" do
    test "generates 12 months of historical data with existing reports" do
      store = insert(:store)

      insert(:report,
        store: store,
        period_start: Date.new!(2024, 1, 1),
        period_end: Date.new!(2024, 1, 31)
      )

      insert(:report,
        store: store,
        period_start: Date.new!(2024, 2, 1),
        period_end: Date.new!(2024, 2, 28)
      )

      store = Repo.preload(store, :reports)

      data = Revenue.generate_historical_data(store, 3, 2024)

      assert length(data) == 12
      assert Enum.find(data, &(&1.month == 1 && &1.year == 2024))
      assert Enum.find(data, &(&1.month == 2 && &1.year == 2024))
    end

    test "generates placeholders for months without reports" do
      store = insert(:store)
      store = Repo.preload(store, :reports)

      data = Revenue.generate_historical_data(store, 3, 2024)

      assert length(data) == 12
      # All should have 0 revenue and pending status
      Enum.each(data, fn entry ->
        assert entry.revenue == Decimal.new(0)
        assert entry.status == :pending
      end)
    end

    test "handles year boundary correctly" do
      store = insert(:store)
      store = Repo.preload(store, :reports)

      data = Revenue.generate_historical_data(store, 12, 2024)

      assert length(data) == 12
      # Months 1-12 should all be 2024
      Enum.each(1..12, fn month ->
        entry = Enum.at(data, month - 1)
        assert entry.month == month
        assert entry.year == 2024
      end)
    end
  end

  describe "calculate_store_area/1" do
    test "returns store area when area is an integer" do
      store = insert(:store, area: 500)

      assert Revenue.calculate_store_area(store) == 500
    end

    test "returns 0 for stores without area field" do
      store = %Revenue.Store{}

      assert Revenue.calculate_store_area(store) == 0
    end

    test "returns 0 when area field is not an integer" do
      store = %Revenue.Store{area: "not_an_integer"}

      assert Revenue.calculate_store_area(store) == 0
    end
  end

  describe "calculate_due_date/1" do
    test "calculates due date as 7 days after period end" do
      period_end = Date.new!(2025, 1, 31)
      due_date = Revenue.calculate_due_date(period_end)

      assert due_date == Date.new!(2025, 2, 7)
    end

    test "handles month boundary" do
      period_end = Date.new!(2025, 1, 28)
      due_date = Revenue.calculate_due_date(period_end)

      assert due_date == Date.new!(2025, 2, 4)
    end
  end

  describe "valid_store_access?/3" do
    test "returns true when hierarchy is valid" do
      group = insert(:group)
      building = insert(:building, group: group)
      store = insert(:store, building: building)

      assert Revenue.valid_store_access?(group, building, store) == true
    end

    test "returns false when building doesn't belong to group" do
      group1 = insert(:group)
      group2 = insert(:group)
      building = insert(:building, group: group1)
      store = insert(:store, building: building)

      refute Revenue.valid_store_access?(group2, building, store)
    end

    test "returns false when store doesn't belong to building" do
      group = insert(:group)
      building1 = insert(:building, group: group)
      building2 = insert(:building, group: group)
      store = insert(:store, building: building1)

      refute Revenue.valid_store_access?(group, building2, store)
    end

    test "returns false when hierarchy is completely wrong" do
      group = insert(:group)
      building = insert(:building, group: group)
      store = insert(:store)

      refute Revenue.valid_store_access?(group, building, store)
    end
  end
end

defmodule Antonia.Revenue do
  @moduledoc """
  The Revenue context.

  This module provides a contract-based interface for all revenue-related operations.
  The web layer should only interact with this module and never directly access
  inner modules like Antonia.Revenue.Store, Antonia.Revenue.Building, etc.

  All functions require user_id parameters for authentication and authorization.
  When the account system is implemented, account_id will be added to all functions.
  """

  import Ecto.Query, warn: false

  require Logger

  alias Antonia.Repo
  alias Antonia.Revenue.Attachment
  alias Antonia.Revenue.Building
  alias Antonia.Revenue.EmailLog
  alias Antonia.Revenue.Group
  alias Antonia.Revenue.Report
  alias Antonia.Revenue.Store

  alias Ecto.Changeset

  ##### Groups #####

  @doc "Lists groups for a user, ordered alphabetically by name."
  @spec list_groups(binary()) :: [Group.t()]
  def list_groups(user_id) do
    Group
    |> where([g], g.created_by_user_id == ^user_id)
    |> order_by([g], asc: g.name)
    |> Repo.all()
  end

  @doc """
  Lists groups for a user with aggregated statistics.

  Returns a list of groups, each enriched with a `:stats` map containing:
  - `buildings_count`: Total number of buildings in the group
  - `stores_count`: Total number of stores in the group
  - `pending_reports_count`: Number of stores without a submitted/approved report for the current month

  Groups are ordered alphabetically by name.

  ## Examples

      iex> Revenue.list_groups_with_stats(user_id)
      [
        %Group{
          name: "My Group",
          stats: %{
            buildings_count: 2,
            stores_count: 5,
            pending_reports_count: 3
          }
        }
      ]
  """
  @spec list_groups_with_stats(binary()) :: [map()]
  def list_groups_with_stats(user_id) do
    current_month = Date.beginning_of_month(Date.utc_today())
    next_month = current_month |> Date.add(32) |> Date.beginning_of_month()

    Group
    |> where([g], g.created_by_user_id == ^user_id)
    |> order_by([g], asc: g.name)
    |> Repo.all()
    |> Enum.map(fn group ->
      stats = calculate_group_stats(group.id, current_month, next_month)
      Map.put(group, :stats, stats)
    end)
  end

  # Private helper to calculate stats for a single group
  defp calculate_group_stats(group_id, current_month, next_month) do
    buildings_count =
      Building
      |> where([b], b.group_id == ^group_id)
      |> Repo.aggregate(:count, :id)

    stores_count =
      Store
      |> join(:inner, [s], b in Building, on: s.building_id == b.id)
      |> where([s, b], b.group_id == ^group_id)
      |> Repo.aggregate(:count, :id)

    # Count stores that have submitted/approved reports for current month
    stores_query =
      from(s in Store,
        join: b in Building,
        on: s.building_id == b.id,
        join: r in Report,
        on: r.store_id == s.id,
        where:
          b.group_id == ^group_id and r.period_start >= ^current_month and
            r.period_start < ^next_month and r.status in [:submitted, :approved],
        distinct: s.id
      )

    stores_with_reports_count = Repo.aggregate(stores_query, :count, :id)

    # Pending = total stores - stores that have completed reports
    pending_reports_count = max(0, stores_count - stores_with_reports_count)

    %{
      buildings_count: buildings_count,
      stores_count: stores_count,
      pending_reports_count: pending_reports_count
    }
  end

  @doc "Gets a group by user ID and group ID."
  @spec get_group(binary(), binary()) :: {:ok, Group.t()} | {:error, :group_not_found}
  def get_group(user_id, group_id) do
    case Repo.get_by(Group, created_by_user_id: user_id, id: group_id) do
      nil -> {:error, :group_not_found}
      group -> {:ok, group}
    end
  end

  @doc "Creates a new group for a user."
  @spec create_group(binary(), map()) :: {:ok, Group.t()} | {:error, Changeset.t()}
  def create_group(user_id, attrs) do
    %Group{}
    |> Group.changeset(Map.put(attrs, :created_by_user_id, user_id))
    |> Repo.insert()
  end

  @doc "Changes a group."
  @spec change_group(Group.t()) :: Ecto.Changeset.t()
  def change_group(group \\ %Group{}) do
    Group.changeset(group, %{})
  end

  ##### Buildings #####

  @doc "Lists buildings for a group, ordered alphabetically by name."
  @spec list_buildings(binary(), binary()) :: [Building.t()]
  def list_buildings(user_id, group_id) do
    # Ensure user owns the group before listing buildings
    case get_group(user_id, group_id) do
      {:error, :group_not_found} ->
        []

      {:ok, _group} ->
        Building
        |> where([b], b.group_id == ^group_id)
        |> order_by([b], asc: b.name)
        |> Repo.all()
    end
  end

  @doc "Gets a building by user ID, group ID, and building ID."
  @spec get_building(binary(), binary(), binary()) :: Building.t() | nil
  def get_building(user_id, group_id, building_id) do
    # Ensure user owns the group before getting building
    case get_group(user_id, group_id) do
      {:error, :group_not_found} ->
        nil

      {:ok, _group} ->
        Building
        |> where([b], b.group_id == ^group_id and b.id == ^building_id)
        |> Repo.one()
    end
  end

  @doc "Creates a new building for a group."
  @spec create_building(binary(), binary(), map()) ::
          {:ok, Building.t()} | {:error, Changeset.t() | :group_not_found}
  def create_building(user_id, group_id, attrs) do
    # Ensure user owns the group before creating building
    case get_group(user_id, group_id) do
      {:error, :group_not_found} ->
        {:error, :group_not_found}

      {:ok, _group} ->
        %Building{}
        |> Building.changeset(Map.put(attrs, :group_id, group_id))
        |> Repo.insert()
    end
  end

  @doc "Changes a building."
  @spec change_building(Building.t()) :: Ecto.Changeset.t()
  def change_building(building \\ %Building{}) do
    Building.changeset(building, %{})
  end

  @doc """
  Lists buildings for a group with aggregated statistics.

  Returns a list of buildings, each enriched with a `:stats` map containing:
  - `total_stores`: Total number of stores in the building
  - `reported_count`: Number of stores with submitted/approved reports for the current month
  - `pending_count`: Number of stores without submitted/approved reports for the current month
  - `completion_percentage`: Percentage of stores that have completed reports (0-100)
  - `unreported_shops`: List of up to 3 store names that don't have reports
  - `status`: Either `:complete` or `:pending` based on whether all stores have reports

  Buildings are ordered alphabetically by name.
  Stores are preloaded with their reports.

  ## Examples

      iex> Revenue.list_buildings_with_stats(user_id, group_id)
      [
        %Building{
          name: "Building A",
          stats: %{
            total_stores: 5,
            reported_count: 3,
            pending_count: 2,
            completion_percentage: 60,
            unreported_shops: ["Store X", "Store Y"],
            status: :pending
          }
        }
      ]
  """
  @spec list_buildings_with_stats(binary(), binary()) :: [map()]
  def list_buildings_with_stats(user_id, group_id) do
    # Ensure user owns the group before listing buildings
    case get_group(user_id, group_id) do
      {:error, :group_not_found} ->
        []

      {:ok, _group} ->
        current_month = Date.beginning_of_month(Date.utc_today())

        Building
        |> where([b], b.group_id == ^group_id)
        |> preload([b], stores: [:reports])
        |> order_by([b], asc: b.name)
        |> Repo.all()
        |> Enum.map(&add_building_stats(&1, current_month))
    end
  end

  @doc """
  Gets dashboard statistics for a group.

  Returns a map containing:
  - `buildings_count`: Total number of buildings in the group
  - `stores_count`: Total number of stores in the group
  - `reported_count`: Number of reports with submitted/approved status for the current month
  - `pending_count`: Number of reports with pending status for the current month

  ## Examples

      iex> Revenue.get_group_dashboard_stats(user_id, group_id)
      %{
        buildings_count: 3,
        stores_count: 10,
        reported_count: 7,
        pending_count: 3
      }
  """
  @spec get_group_dashboard_stats(binary(), binary()) ::
          {:ok, map()} | {:error, :group_not_found}
  def get_group_dashboard_stats(user_id, group_id) do
    case get_group(user_id, group_id) do
      {:error, :group_not_found} = error ->
        error

      {:ok, _group} ->
        current_month = Date.beginning_of_month(Date.utc_today())
        next_month = current_month |> Date.add(32) |> Date.beginning_of_month()

        stats = calculate_dashboard_stats(group_id, current_month, next_month)
        {:ok, stats}
    end
  end

  # Private helper to calculate stats for a single building
  defp add_building_stats(building, current_month) do
    stores = building.stores
    total_stores = length(stores)

    {reported_stores, pending_stores} =
      Enum.split_with(stores, fn store ->
        has_current_month_report?(store, current_month)
      end)

    reported_count = length(reported_stores)
    pending_count = length(pending_stores)

    completion_percentage =
      if total_stores > 0, do: round(reported_count / total_stores * 100), else: 0

    unreported_shops =
      pending_stores
      |> Enum.take(3)
      |> Enum.map(& &1.name)

    Map.put(building, :stats, %{
      total_stores: total_stores,
      reported_count: reported_count,
      pending_count: pending_count,
      completion_percentage: completion_percentage,
      unreported_shops: unreported_shops,
      status: if(pending_count == 0, do: :complete, else: :pending)
    })
  end

  # Private helper to check if a store has a current month report
  defp has_current_month_report?(store, current_month) do
    next_month = current_month |> Date.add(32) |> Date.beginning_of_month()

    Enum.any?(store.reports, fn report ->
      Date.compare(report.period_start, current_month) != :lt and
        Date.compare(report.period_end, next_month) == :lt and
        report.status in [:submitted, :approved]
    end)
  end

  # Private helper to calculate dashboard stats for a group
  defp calculate_dashboard_stats(group_id, current_month, next_month) do
    buildings_count =
      Building
      |> where([b], b.group_id == ^group_id)
      |> Repo.aggregate(:count, :id)

    stores_count =
      Store
      |> join(:inner, [s], b in Building, on: s.building_id == b.id)
      |> where([s, b], b.group_id == ^group_id)
      |> Repo.aggregate(:count, :id)

    # Count reports for current month in this group
    current_month_reports =
      from(r in Report,
        join: s in Store,
        on: r.store_id == s.id,
        join: b in Building,
        on: s.building_id == b.id,
        where:
          b.group_id == ^group_id and r.period_start >= ^current_month and
            r.period_start < ^next_month
      )

    reported_count =
      current_month_reports
      |> where([r], r.status in [:submitted, :approved])
      |> Repo.aggregate(:count, :id)

    pending_count =
      current_month_reports
      |> where([r], r.status == :pending)
      |> Repo.aggregate(:count, :id)

    %{
      buildings_count: buildings_count,
      stores_count: stores_count,
      reported_count: reported_count,
      pending_count: pending_count
    }
  end

  ##### Stores #####

  @doc "Lists stores for a building, ordered alphabetically by name."
  @spec list_stores(binary(), binary(), binary()) :: [Store.t()]
  def list_stores(user_id, group_id, building_id) do
    # Ensure user owns the group before listing stores
    case get_group(user_id, group_id) do
      {:error, :group_not_found} ->
        []

      {:ok, _group} ->
        Store
        |> join(:inner, [s], b in assoc(s, :building))
        |> where([s, b], b.group_id == ^group_id and b.id == ^building_id)
        |> order_by([s], asc: s.name)
        |> Repo.all()
    end
  end

  @doc "Gets a store by user ID, group ID, building ID, and store ID."
  @spec get_store(binary(), binary(), binary(), binary()) ::
          {:ok, Store.t()} | {:error, :store_not_found | :group_not_found}
  def get_store(user_id, group_id, building_id, store_id) do
    # Ensure user owns the group before getting store
    case get_group(user_id, group_id) do
      {:error, :group_not_found} ->
        {:error, :group_not_found}

      {:ok, _group} ->
        store =
          Store
          |> join(:inner, [s], b in assoc(s, :building))
          |> where([s, b], b.group_id == ^group_id and b.id == ^building_id and s.id == ^store_id)
          |> preload(:reports)
          |> Repo.one()

        case store do
          nil -> {:error, :store_not_found}
          store -> {:ok, store}
        end
    end
  end

  @doc "Creates a new store for a building."
  @spec create_store(binary(), binary(), binary(), map()) ::
          {:ok, Store.t()} | {:error, Changeset.t() | :group_not_found}
  def create_store(user_id, group_id, building_id, attrs) do
    # Ensure user owns the group before creating store
    case get_group(user_id, group_id) do
      {:error, :group_not_found} ->
        {:error, :group_not_found}

      {:ok, _group} ->
        %Store{}
        |> Store.changeset(Map.put(attrs, :building_id, building_id))
        |> Repo.insert()
    end
  end

  @doc "Changes a store."
  @spec change_store(Store.t()) :: Ecto.Changeset.t()
  def change_store(store \\ %Store{}) do
    Store.changeset(store, %{})
  end

  ##### Reports #####

  @doc "Lists reports for a store."
  @spec list_reports(binary(), binary(), binary(), binary()) :: [Report.t()]
  def list_reports(user_id, group_id, building_id, store_id) do
    # Ensure user owns the group before listing reports
    case get_group(user_id, group_id) do
      {:error, :group_not_found} ->
        []

      {:ok, _group} ->
        Report
        |> join(:inner, [r], s in assoc(r, :store))
        |> join(:inner, [r, s], b in assoc(s, :building))
        |> where(
          [r, s, b],
          b.group_id == ^group_id and b.id == ^building_id and s.id == ^store_id
        )
        |> order_by([r], desc: r.inserted_at)
        |> Repo.all()
    end
  end

  @doc "Gets a report by user ID, group ID, building ID, store ID, and report ID."
  @spec get_report(binary(), binary(), binary(), binary(), binary()) ::
          {:ok, Report.t()} | {:error, :report_not_found}
  def get_report(_user_id, group_id, building_id, store_id, report_id) do
    report =
      Report
      |> join(:inner, [r], s in assoc(r, :store))
      |> join(:inner, [r, s], b in assoc(s, :building))
      |> where(
        [r, s, b],
        b.group_id == ^group_id and b.id == ^building_id and s.id == ^store_id and
          r.id == ^report_id
      )
      |> Repo.one()

    case report do
      nil -> {:error, :report_not_found}
      report -> {:ok, report}
    end
  end

  @doc "Creates a new report for a store."
  @spec create_report(binary(), binary(), binary(), binary(), map()) ::
          {:ok, Report.t()} | {:error, Changeset.t() | :group_not_found}
  def create_report(user_id, group_id, _building_id, store_id, attrs) do
    # Ensure user owns the group before creating report
    case get_group(user_id, group_id) do
      {:error, :group_not_found} ->
        {:error, :group_not_found}

      {:ok, _group} ->
        %Report{}
        |> Report.changeset(Map.put(attrs, :store_id, store_id))
        |> Repo.insert()
    end
  end

  @doc "Updates a report."
  @spec update_report(binary(), binary(), binary(), binary(), binary(), map()) ::
          {:ok, Report.t()} | {:error, Changeset.t() | :report_not_found | :group_not_found}
  def update_report(user_id, group_id, building_id, store_id, report_id, attrs) do
    # Ensure user owns the group before updating report
    with {:ok, _group} <- get_group(user_id, group_id),
         {:ok, report} <- get_report(user_id, group_id, building_id, store_id, report_id) do
      report
      |> Report.changeset(attrs)
      |> Repo.update()
    end
  end

  @doc "Changes a report."
  @spec change_report(Report.t()) :: Ecto.Changeset.t()
  def change_report(report \\ %Report{}) do
    Report.changeset(report, %{})
  end

  @doc "Upserts a report. Creates new if nil, updates if exists."
  @spec upsert_report(binary(), binary(), binary(), binary(), Report.t() | nil, map()) ::
          {:ok, Report.t()} | {:error, Changeset.t() | :group_not_found | :store_not_found}
  def upsert_report(user_id, group_id, building_id, store_id, existing_report, attrs \\ %{}) do
    with {:ok, group} <- get_group(user_id, group_id),
         {:ok, store} <- get_store(user_id, group_id, building_id, store_id) do
      report_params = build_report_params(existing_report, attrs, store, group)
      changeset = Report.changeset(existing_report || %Report{}, report_params)

      Repo.insert(changeset,
        on_conflict:
          {:replace_all_except, [:id, :inserted_at, :store_id, :period_start, :period_end]},
        conflict_target: [:store_id, :period_start]
      )
    end
  end

  @doc "Public function to update a report via submission token (no authentication required)"
  @spec update_report_via_token(Report.t(), map()) ::
          {:ok, Report.t()} | {:error, Changeset.t()}
  def update_report_via_token(report, attrs) do
    # Preload store and building to get group for currency
    report = Repo.preload(report, store: [building: :group])
    store = report.store
    group = store.building.group

    report_params = build_report_params(report, attrs, store, group)
    changeset = Report.changeset(report, report_params)

    Repo.update(changeset)
  end

  defp build_report_params(existing_report, attrs, store, group) do
    {period_start, period_end} = get_period(existing_report, attrs)
    revenue_decimal = normalize_revenue(attrs[:revenue] || "0")
    status = determine_status(existing_report, attrs)
    currency = determine_currency(existing_report, attrs, group)

    %{
      store_id: store.id,
      revenue: revenue_decimal,
      period_start: period_start,
      period_end: period_end,
      currency: currency,
      status: status,
      note: attrs[:note]
    }
  end

  defp determine_status(nil, attrs) do
    attrs[:status] || :approved
  end

  defp determine_status(existing_report, attrs) do
    attrs[:status] || existing_report.status || :approved
  end

  defp determine_currency(existing_report, attrs, group) do
    cond do
      not is_nil(attrs[:currency]) -> attrs[:currency]
      is_nil(existing_report) -> group.default_currency || "EUR"
      true -> existing_report.currency || group.default_currency || "EUR"
    end
  end

  defp get_period(nil, attrs) do
    year = attrs[:year] || Date.utc_today().year
    month = attrs[:month] || Date.utc_today().month
    start = Date.new!(year, month, 1)
    {start, Date.end_of_month(start)}
  end

  defp get_period(existing_report, _attrs) do
    {existing_report.period_start, existing_report.period_end}
  end

  @doc "Normalizes revenue value to Decimal."
  @spec normalize_revenue(number() | binary() | Decimal.t()) :: Decimal.t()
  def normalize_revenue(revenue) when is_float(revenue) do
    revenue |> :erlang.float_to_binary(decimals: 2) |> Decimal.new()
  end

  def normalize_revenue(revenue) when is_integer(revenue), do: Decimal.new(revenue)
  def normalize_revenue(revenue) when is_binary(revenue), do: Decimal.new(revenue)
  def normalize_revenue(%Decimal{} = revenue), do: revenue
  def normalize_revenue(_), do: Decimal.new("0")

  ##### Business Logic Helpers #####

  @doc "Finds a report for a specific period (year/month)."
  @spec find_report_for_period([Report.t()], integer(), integer()) :: Report.t() | nil
  def find_report_for_period(reports, year, month) do
    Enum.find(reports, fn report ->
      report.period_start.year == year and report.period_start.month == month
    end)
  end

  @doc "Generates historical data for a store."
  @spec generate_historical_data(Store.t(), integer(), integer()) :: [map()]
  def generate_historical_data(store, current_month, current_year) do
    # Generate 12 months of historical data
    Enum.map(1..12, fn month ->
      year = if month > current_month, do: current_year - 1, else: current_year

      report = find_report_for_period(store.reports || [], year, month)

      revenue = if report && report.revenue, do: report.revenue, else: Decimal.new("0")

      %{
        year: year,
        month: month,
        revenue: revenue,
        status: if(report, do: report.status, else: :pending),
        due_date:
          if(report, do: report.due_date, else: calculate_due_date(Date.new!(year, month, 1)))
      }
    end)
  end

  @doc "Calculates store area."
  @spec calculate_store_area(Store.t()) :: integer()
  def calculate_store_area(%Store{area: area}) when is_integer(area), do: area
  def calculate_store_area(_), do: 0

  @doc "Calculates due date based on period end (7 days after period end)."
  @spec calculate_due_date(Date.t()) :: Date.t()
  def calculate_due_date(period_end) do
    Date.add(period_end, 7)
  end

  @doc "Validates store access within group/building hierarchy."
  @spec valid_store_access?(Group.t(), Building.t(), Store.t()) :: boolean()
  def valid_store_access?(
        %Group{id: group_id},
        %Building{id: building_id, group_id: group_id},
        %Store{building_id: building_id}
      ),
      do: true

  def valid_store_access?(_, _, _), do: false

  ##### Admin Functions #####

  @doc "Lists all stores (for admin panel)."
  @spec list_stores() :: [Store.t()]
  def list_stores do
    Repo.all(Store)
  end

  @doc "Creates a new store (for admin panel)."
  @spec create_store(map()) :: {:ok, Store.t()} | {:error, Ecto.Changeset.t()}
  def create_store(attrs) do
    %Store{}
    |> Store.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Deletes a store (for admin panel)."
  @spec delete_store(Store.t()) :: {:ok, Store.t()} | {:error, Ecto.Changeset.t()}
  def delete_store(%Store{} = store) do
    Repo.delete(store)
  end

  ##### Admin Functions for Groups #####

  @doc "Lists all groups (for admin panel)."
  @spec list_groups() :: [Group.t()]
  def list_groups do
    Repo.all(Group)
  end

  @doc "Creates a new group (for admin panel)."
  @spec create_group(map()) :: {:ok, Group.t()} | {:error, Ecto.Changeset.t()}
  def create_group(attrs) do
    %Group{}
    |> Group.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Deletes a group (for admin panel)."
  @spec delete_group(Group.t()) :: {:ok, Group.t()} | {:error, Ecto.Changeset.t()}
  def delete_group(%Group{} = group) do
    Repo.delete(group)
  end

  ##### Admin Functions for Buildings #####

  @doc "Lists all buildings (for admin panel)."
  @spec list_buildings() :: [Building.t()]
  def list_buildings do
    Repo.all(Building)
  end

  @doc "Creates a new building (for admin panel)."
  @spec create_building(map()) :: {:ok, Building.t()} | {:error, Ecto.Changeset.t()}
  def create_building(attrs) do
    %Building{}
    |> Building.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Deletes a building (for admin panel)."
  @spec delete_building(Building.t()) :: {:ok, Building.t()} | {:error, Ecto.Changeset.t()}
  def delete_building(%Building{} = building) do
    Repo.delete(building)
  end

  ##### Admin Functions for Reports #####

  @doc "Lists all reports (for admin panel)."
  @spec list_reports() :: [Report.t()]
  def list_reports do
    Repo.all(Report)
  end

  @doc "Creates a new report (for admin panel)."
  @spec create_report(map()) :: {:ok, Report.t()} | {:error, Ecto.Changeset.t()}
  def create_report(attrs) do
    %Report{}
    |> Report.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Deletes a report (for admin panel)."
  @spec delete_report(Report.t()) :: {:ok, Report.t()} | {:error, Ecto.Changeset.t()}
  def delete_report(%Report{} = report) do
    Repo.delete(report)
  end

  ##### Admin Functions for Attachments #####

  @doc "Lists all attachments (for admin panel)."
  @spec list_attachments() :: [Attachment.t()]
  def list_attachments do
    Repo.all(Attachment)
  end

  @doc "Creates a new attachment (for admin panel)."
  @spec create_attachment(map()) :: {:ok, Attachment.t()} | {:error, Ecto.Changeset.t()}
  def create_attachment(attrs) do
    %Attachment{}
    |> Attachment.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Deletes an attachment (for admin panel)."
  @spec delete_attachment(Attachment.t()) :: {:ok, Attachment.t()} | {:error, Ecto.Changeset.t()}
  def delete_attachment(%Attachment{} = attachment) do
    Repo.delete(attachment)
  end

  ##### Admin Functions for EmailLogs #####

  @doc "Lists all email logs (for admin panel)."
  @spec list_email_logs() :: [EmailLog.t()]
  def list_email_logs do
    Repo.all(EmailLog)
  end

  @doc "Creates a new email log (for admin panel)."
  @spec create_email_log(map()) :: {:ok, EmailLog.t()} | {:error, Ecto.Changeset.t()}
  def create_email_log(attrs) do
    %EmailLog{}
    |> EmailLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Deletes an email log (for admin panel)."
  @spec delete_email_log(EmailLog.t()) :: {:ok, EmailLog.t()} | {:error, Ecto.Changeset.t()}
  def delete_email_log(%EmailLog{} = email_log) do
    Repo.delete(email_log)
  end
end

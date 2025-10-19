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
  alias Antonia.Revenue.Building
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
  @spec get_store(binary(), binary(), binary(), binary()) :: Store.t() | nil
  def get_store(user_id, group_id, building_id, store_id) do
    # Ensure user owns the group before getting store
    case get_group(user_id, group_id) do
      {:error, :group_not_found} ->
        nil

      {:ok, _group} ->
        Store
        |> join(:inner, [s], b in assoc(s, :building))
        |> where([s, b], b.group_id == ^group_id and b.id == ^building_id and s.id == ^store_id)
        |> preload(:reports)
        |> Repo.one()
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

      report = find_report_for_period(store.reports, year, month)

      %{
        year: year,
        month: month,
        revenue: if(report, do: report.revenue, else: Decimal.new(0)),
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
end

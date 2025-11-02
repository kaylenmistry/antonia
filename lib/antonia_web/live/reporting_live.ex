defmodule AntoniaWeb.ReportingLive do
  @moduledoc "LiveView for reporting dashboard of a specific group"
  use AntoniaWeb, :live_view

  import Ecto.Query
  import AntoniaWeb.FormHelpers, only: [format_params: 1]
  import AntoniaWeb.SharedComponents

  alias Antonia.Repo
  alias Antonia.Revenue.Building
  alias Antonia.Revenue.Group
  alias Antonia.Revenue.Report
  alias Antonia.Revenue.Store

  @impl Phoenix.LiveView
  def mount(%{"id" => group_id}, %{"auth" => auth}, socket) do
    group = Repo.get(Group, group_id)

    if group do
      send(self(), {:fetch_data, group_id})

      {:ok,
       socket
       |> assign(:group, group)
       |> assign(:buildings, nil)
       |> assign(:dashboard_stats, nil)
       |> assign(:form, to_form(Building.changeset(%Building{}, %{group_id: group_id})))
       |> assign(:user, auth.info)}
    else
      {:ok,
       socket
       |> put_flash(:error, gettext("Group not found"))
       |> push_navigate(to: ~p"/app")}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:fetch_data, group_id}, socket) do
    buildings = load_buildings_with_stats(group_id)
    dashboard_stats = calculate_group_stats(group_id)

    {:noreply,
     socket
     |> assign(:buildings, buildings)
     |> assign(:dashboard_stats, dashboard_stats)}
  end

  @impl Phoenix.LiveView
  def handle_event("dialog_closed", _, socket) do
    form = to_form(Building.changeset(%Building{}, %{group_id: socket.assigns.group.id}))
    {:noreply, assign(socket, :form, form)}
  end

  @impl Phoenix.LiveView
  def handle_event("create_building", %{"building" => params}, socket) do
    formatted_params = format_params(params)
    formatted_params = Map.put(formatted_params, :group_id, socket.assigns.group.id)

    case %Building{}
         |> Building.changeset(formatted_params)
         |> Repo.insert() do
      {:ok, building} ->
        # Reload buildings and stats to include the new one
        send(self(), {:fetch_data, socket.assigns.group.id})

        socket =
          socket
          |> put_flash(:info, gettext("Created building") <> " '" <> building.name <> "'")
          |> assign(
            :form,
            to_form(Building.changeset(%Building{}, %{group_id: socket.assigns.group.id}))
          )
          |> push_event("close-dialog", %{id: "add-building-dialog"})

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("navigate_to_building", %{"building_id" => building_id}, socket) do
    {:noreply,
     push_navigate(socket,
       to: ~p"/app/groups/#{socket.assigns.group.id}/buildings/#{building_id}"
     )}
  end

  # Private helper functions

  defp load_buildings_with_stats(group_id) do
    Building
    |> where([b], b.group_id == ^group_id)
    |> preload([b], stores: [:reports])
    |> Repo.all()
    |> Enum.map(&add_building_stats/1)
  end

  defp add_building_stats(building) do
    stores = building.stores
    total_stores = length(stores)

    current_month = Date.beginning_of_month(Date.utc_today())

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

  defp has_current_month_report?(store, current_month) do
    next_month = current_month |> Date.add(32) |> Date.beginning_of_month()

    Enum.any?(store.reports, fn report ->
      Date.compare(report.period_start, current_month) != :lt and
        Date.compare(report.period_end, next_month) == :lt and
        report.status in [:submitted, :approved]
    end)
  end

  defp calculate_group_stats(group_id) do
    buildings_count =
      Building
      |> where([b], b.group_id == ^group_id)
      |> Repo.aggregate(:count, :id)

    stores_count =
      Store
      |> join(:inner, [s], b in Building, on: s.building_id == b.id)
      |> where([s, b], b.group_id == ^group_id)
      |> Repo.aggregate(:count, :id)

    current_month = Date.beginning_of_month(Date.utc_today())
    next_month = Date.add(current_month, 32)
    Date.beginning_of_month(next_month)

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
end

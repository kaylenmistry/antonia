defmodule AntoniaWeb.BuildingLive do
  @moduledoc """
  LiveView for managing buildings within a group.
  """
  use AntoniaWeb, :live_view

  import AntoniaWeb.SharedComponents
  import AntoniaWeb.FormHelpers, only: [format_params: 1]
  import Ecto.Query

  alias Antonia.Repo
  alias Antonia.Revenue.Building
  alias Antonia.Revenue.Group
  alias Antonia.Revenue.Report
  alias Antonia.Revenue.Store

  @impl Phoenix.LiveView
  def mount(%{"id" => group_id, "building_id" => building_id}, %{"auth" => auth}, socket) do
    group = Repo.get(Group, group_id)
    building = Repo.get(Building, building_id)
    building = Repo.preload(building, [:group, :stores])

    if group && building && building.group_id == group.id do
      stores = load_stores_with_revenue_data(building_id)
      revenue_data = build_revenue_table_data(stores)

      socket =
        socket
        |> assign(:group, group)
        |> assign(:building, building)
        |> assign(:stores, stores)
        |> assign(:revenue_data, revenue_data)
        |> assign(:form, to_form(Store.changeset(%Store{}, %{building_id: building_id})))
        |> assign(:user, auth.info)

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "Building not found")
       |> push_navigate(to: ~p"/app")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("create_store", %{"store" => store_params}, socket) do
    formatted_params = format_params(store_params)
    formatted_params = Map.put(formatted_params, :building_id, socket.assigns.building.id)

    case Repo.insert(Store.changeset(%Store{}, formatted_params)) do
      {:ok, store} ->
        stores = load_stores_with_revenue_data(socket.assigns.building.id)
        revenue_data = build_revenue_table_data(stores)

        socket =
          socket
          |> assign(:stores, stores)
          |> assign(:revenue_data, revenue_data)
          |> assign(
            :form,
            to_form(Store.changeset(%Store{}, %{building_id: socket.assigns.building.id}))
          )
          |> put_flash(:info, gettext("Created store") <> " '" <> store.name <> "'")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("back_to_group", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/app/groups/#{socket.assigns.group.id}")}
  end

  @impl Phoenix.LiveView
  def handle_event("dialog_closed", _params, socket) do
    {:noreply,
     assign(
       socket,
       :form,
       to_form(Store.changeset(%Store{}, %{building_id: socket.assigns.building.id}))
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("export_excel", _params, socket) do
    # For now, just show a flash message. In a real implementation,
    # you'd generate and download an Excel file
    {:noreply, put_flash(socket, :info, gettext("Excel export functionality coming soon"))}
  end

  # Private helper functions

  defp load_stores_with_revenue_data(building_id) do
    # Create the ordered reports query
    reports_query = from(r in Report, order_by: [desc: r.period_start])

    Store
    |> where([s], s.building_id == ^building_id)
    |> preload([s], reports: ^reports_query)
    |> Repo.all()
    |> Enum.map(&add_store_revenue_stats/1)
  end

  defp add_store_revenue_stats(store) do
    # Calculate area (mock data for now - you'd add this field to the Store schema)
    area = calculate_store_area(store)

    # Group reports by year and month
    revenue_by_period = group_reports_by_period(store.reports)

    Map.merge(store, %{
      area: area,
      revenue_by_period: revenue_by_period
    })
  end

  defp calculate_store_area(store) do
    # Use the actual area from the database, fallback to 100 if not set
    store.area || 100
  end

  defp group_reports_by_period(reports) do
    current_year = Date.utc_today().year
    years = [current_year, current_year - 1, current_year - 2]

    Enum.reduce(years, %{}, fn year, acc ->
      year_data = build_year_data(reports, year)
      Map.put(acc, year, year_data)
    end)
  end

  defp build_year_data(reports, year) do
    Enum.reduce(1..12, %{}, fn month, month_acc ->
      month_data = build_month_data(reports, year, month)
      Map.put(month_acc, month, month_data)
    end)
  end

  defp build_month_data(reports, year, month) do
    report = find_report_for_period(reports, year, month)
    revenue = if report, do: Decimal.to_float(report.revenue), else: 0.0

    # Calculate percentage change vs previous year
    prev_year_report = find_report_for_period(reports, year - 1, month)

    prev_year_revenue =
      if prev_year_report, do: Decimal.to_float(prev_year_report.revenue), else: 0.0

    percentage_change = calculate_percentage_change(revenue, prev_year_revenue)

    %{
      revenue: revenue,
      percentage_change: percentage_change,
      report: report
    }
  end

  defp find_report_for_period(reports, year, month) do
    Enum.find(reports, fn report ->
      report.period_start.year == year and report.period_start.month == month
    end)
  end

  defp calculate_percentage_change(current, previous) when previous > 0 do
    result = (current - previous) / previous * 100
    Float.round(result, 1)
  end

  defp calculate_percentage_change(current, 0) when current > 0, do: 100.0
  defp calculate_percentage_change(_, _), do: nil

  defp build_revenue_table_data(stores) do
    current_year = Date.utc_today().year
    years = [current_year, current_year - 1, current_year - 2]
    months = Enum.to_list(1..12)

    %{
      years: years,
      months: months,
      month_names: [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec"
      ],
      stores: stores,
      totals_by_year: calculate_yearly_totals(stores, years)
    }
  end

  defp calculate_yearly_totals(stores, years) do
    Enum.reduce(years, %{}, fn year, acc ->
      year_total = calculate_year_total(stores, year)
      prev_year_total = Map.get(acc, year - 1, 0)
      yoy_change = calculate_percentage_change(year_total, prev_year_total)
      Map.put(acc, year, %{total: year_total, yoy_change: yoy_change})
    end)
  end

  defp calculate_year_total(stores, year) do
    Enum.reduce(stores, 0, fn store, store_acc ->
      year_revenue = calculate_store_year_revenue(store, year)
      store_acc + year_revenue
    end)
  end

  defp calculate_store_year_revenue(store, year) do
    Enum.reduce(1..12, 0, fn month, month_acc ->
      revenue = get_in(store.revenue_by_period, [year, month, :revenue]) || 0
      month_acc + revenue
    end)
  end
end

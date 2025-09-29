defmodule AntoniaWeb.StoreLive do
  @moduledoc """
  LiveView for revenue detail management of a specific store.
  """
  use AntoniaWeb, :live_view

  alias Antonia.Repo
  alias Antonia.Revenue.Building
  alias Antonia.Revenue.Group
  alias Antonia.Revenue.Report
  alias Antonia.Revenue.Store

  @impl Phoenix.LiveView
  def mount(
        %{"id" => group_id, "building_id" => building_id, "store_id" => store_id} = params,
        %{"auth" => auth},
        socket
      ) do
    case load_store_data(group_id, building_id, store_id, params) do
      {:ok, data} ->
        socket = assign_store_data(socket, data, auth.info)
        {:ok, socket}

      {:error, reason} ->
        {:ok, handle_mount_error(socket, reason, group_id)}
    end
  end

  defp load_store_data(group_id, building_id, store_id, params) do
    with {:ok, group} <- get_group(group_id),
         {:ok, building} <- get_building(building_id),
         {:ok, store} <- get_store(store_id),
         {:ok, year_month} <- parse_year_month(params) do
      if valid_store_access?(group, building, store) do
        current_report = find_report_for_period(store.reports, year_month.year, year_month.month)
        historical_data = generate_historical_data(store, year_month.month, year_month.year)
        area = calculate_store_area(store)
        store_with_area = Map.put(store, :area, area)

        {:ok,
         %{
           group: group,
           building: building,
           store: store_with_area,
           year: year_month.year,
           month: year_month.month,
           current_report: current_report,
           historical_data: historical_data
         }}
      else
        {:error, :invalid_access}
      end
    else
      _ -> {:error, :not_found}
    end
  end

  defp get_group(group_id) do
    case Repo.get(Group, group_id) do
      nil -> {:error, :group_not_found}
      group -> {:ok, group}
    end
  end

  defp get_building(building_id) do
    case Repo.get(Building, building_id) do
      nil -> {:error, :building_not_found}
      building -> {:ok, Repo.preload(building, [:group])}
    end
  end

  defp get_store(store_id) do
    case Repo.get(Store, store_id) do
      nil -> {:error, :store_not_found}
      store -> {:ok, Repo.preload(store, [:reports])}
    end
  end

  defp parse_year_month(params) do
    current_date = Date.utc_today()
    year = Map.get(params, "year", to_string(current_date.year))
    year = String.to_integer(year)
    month = Map.get(params, "month", to_string(current_date.month))
    month = String.to_integer(month)
    {:ok, %{year: year, month: month}}
  end

  defp valid_store_access?(group, building, store) do
    group && building && store && building.group_id == group.id &&
      store.building_id == building.id
  end

  defp assign_store_data(socket, data, user) do
    revenue =
      if data.current_report && data.current_report.revenue,
        do: Decimal.to_float(data.current_report.revenue),
        else: 0

    note = if data.current_report, do: data.current_report.note, else: ""

    socket
    |> assign(:group, data.group)
    |> assign(:building, data.building)
    |> assign(:store, data.store)
    |> assign(:year, data.year)
    |> assign(:month, data.month)
    |> assign(:current_report, data.current_report)
    |> assign(:historical_data, data.historical_data)
    |> assign(:is_editing, false)
    |> assign(:edited_revenue, revenue)
    |> assign(:note, note)
    |> assign(:selected_file, nil)
    |> assign(:user, user)
  end

  defp handle_mount_error(socket, :invalid_access, group_id) do
    socket
    |> put_flash(:error, "Store not found")
    |> push_navigate(to: ~p"/app/groups/#{group_id}")
  end

  defp handle_mount_error(socket, :not_found, group_id) do
    socket
    |> put_flash(:error, "Store not found")
    |> push_navigate(to: ~p"/app/groups/#{group_id}")
  end

  @impl Phoenix.LiveView
  def handle_event("back_to_building", _params, socket) do
    {:noreply,
     push_navigate(socket,
       to: ~p"/app/groups/#{socket.assigns.group.id}/buildings/#{socket.assigns.building.id}"
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("start_editing", _params, socket) do
    {:noreply, assign(socket, :is_editing, true)}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel_editing", _params, socket) do
    original_revenue =
      (socket.assigns.current_report && Decimal.to_float(socket.assigns.current_report.revenue)) ||
        0

    original_note = (socket.assigns.current_report && socket.assigns.current_report.note) || ""

    socket =
      socket
      |> assign(:is_editing, false)
      |> assign(:edited_revenue, original_revenue)
      |> assign(:note, original_note)
      |> assign(:selected_file, nil)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("update_revenue", %{"revenue" => revenue_str}, socket) do
    revenue =
      try do
        String.to_float(revenue_str || "0")
      rescue
        _ -> 0
      end

    {:noreply, assign(socket, :edited_revenue, revenue)}
  end

  @impl Phoenix.LiveView
  def handle_event("update_note", %{"note" => note}, socket) do
    {:noreply, assign(socket, :note, note)}
  end

  @impl Phoenix.LiveView
  def handle_event("save_revenue", _params, socket) do
    %{
      store: store,
      year: year,
      month: month,
      edited_revenue: revenue,
      note: note,
      current_report: current_report
    } = socket.assigns

    # Create period dates
    period_start = Date.new!(year, month, 1)
    period_end = Date.end_of_month(period_start)

    report_params = %{
      store_id: store.id,
      revenue: Decimal.new(revenue),
      period_start: period_start,
      period_end: period_end,
      currency: "EUR",
      status: :submitted,
      note: note
    }

    result =
      if current_report do
        # Update existing report
        current_report
        |> Report.changeset(report_params)
        |> Repo.update()
      else
        # Create new report
        %Report{}
        |> Report.changeset(report_params)
        |> Repo.insert()
      end

    case result do
      {:ok, updated_report} ->
        # Reload store with updated reports
        store = Repo.get(Store, store.id)
        store = Repo.preload(store, [:reports])
        # Re-add the area field
        area = calculate_store_area(store)
        store_with_area = Map.put(store, :area, area)
        historical_data = generate_historical_data(store_with_area, month, year)

        socket =
          socket
          |> assign(:store, store_with_area)
          |> assign(:current_report, updated_report)
          |> assign(:historical_data, historical_data)
          |> assign(:is_editing, false)
          |> assign(:selected_file, nil)
          |> put_flash(:info, gettext("Revenue updated successfully"))

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to update revenue"))}
    end
  end

  # Private helper functions

  defp find_report_for_period(reports, year, month) do
    Enum.find(reports, fn report ->
      report.period_start.year == year and report.period_start.month == month
    end)
  end

  defp generate_historical_data(store, month, year) do
    current_year = Date.utc_today().year
    years = [current_year, current_year - 1, current_year - 2]

    historical_data =
      Enum.map(years, fn hist_year ->
        if hist_year == year do
          build_current_year_data(store, hist_year, month)
        else
          build_mock_historical_data(store, hist_year, month, current_year)
        end
      end)

    Enum.sort_by(historical_data, & &1.year, :desc)
  end

  defp build_current_year_data(store, hist_year, month) do
    report = find_report_for_period(store.reports, hist_year, month)
    revenue = if report && report.revenue, do: Decimal.to_float(report.revenue), else: 0
    %{year: hist_year, revenue: revenue, is_current: true}
  end

  defp build_mock_historical_data(store, hist_year, month, current_year) do
    base_revenue = (store.area || 100) * 50
    variations = [0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 0.7, 0.85, 1.15, 0.95, 1.05, 1.25]
    variation = Enum.at(variations, month - 1, 1.0)
    seasonal_multiplier = if month >= 11 or month <= 2, do: 1.3, else: 1.0
    year_growth = calculate_year_growth(hist_year, current_year)

    revenue = base_revenue * variation * seasonal_multiplier * year_growth
    revenue = round(revenue)
    %{year: hist_year, revenue: revenue, is_current: false}
  end

  defp calculate_year_growth(hist_year, current_year) do
    case hist_year do
      y when y == current_year - 1 -> 1.05
      y when y == current_year -> 1.08
      _ -> 1.0
    end
  end

  defp calculate_store_area(store) do
    # Use the actual area from the database, fallback to 100 if not set
    store.area || 100
  end

  defp format_currency(amount) when is_number(amount) do
    amount = :erlang.float_to_binary(amount * 1.0, decimals: 0)
    amount = String.replace(amount, ~r/\B(?=(\d{3})+(?!\d))/, ",")
    "€#{amount}"
  end

  defp format_currency(_), do: "€0"

  defp month_name(month) do
    month_names = [
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
    ]

    Enum.at(month_names, month - 1, "Unknown")
  end
end

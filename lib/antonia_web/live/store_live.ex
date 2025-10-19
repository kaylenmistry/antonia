defmodule AntoniaWeb.StoreLive do
  @moduledoc """
  LiveView for revenue detail management of a specific store.
  """
  use AntoniaWeb, :live_view

  alias Antonia.Repo
  alias Antonia.Revenue
  alias Antonia.Revenue.Report
  alias Antonia.Revenue.Store

  @impl Phoenix.LiveView
  def mount(
        %{"id" => group_id, "building_id" => building_id, "store_id" => store_id} = params,
        %{"auth" => auth},
        socket
      ) do
    user_id = auth.uid
    send(self(), {:fetch_store_data, user_id, group_id, building_id, store_id, params})

    {:ok,
     assign(socket,
       user: auth.info,
       user_id: user_id,
       group_id: group_id,
       building_id: building_id,
       store_id: store_id,
       group: %{name: ""},
       building: %{name: ""},
       store: %{name: ""},
       year: Date.utc_today().year,
       month: Date.utc_today().month,
       current_report: nil,
       historical_data: [],
       loading?: true,
       is_editing: false,
       edited_revenue: 0,
       note: "",
       selected_file: nil
     )}
  end

  @impl Phoenix.LiveView
  def handle_info({:fetch_store_data, user_id, group_id, building_id, store_id, params}, socket) do
    case load_store_data(user_id, group_id, building_id, store_id, params) do
      {:ok, data} ->
        {:noreply,
         assign(socket,
           group: data.group,
           building: data.building,
           store: data.store,
           year: data.year,
           month: data.month,
           current_report: data.current_report,
           historical_data: data.historical_data,
           loading?: false
         )}

      {:error, reason} ->
        {:noreply, handle_mount_error(socket, reason, group_id)}
    end
  end

  defp load_store_data(user_id, group_id, building_id, store_id, params) do
    with {:ok, group} <- get_group(user_id, group_id),
         {:ok, building} <- get_building(user_id, group_id, building_id),
         {:ok, store} <- get_store(user_id, group_id, building_id, store_id),
         {:ok, year_month} <- parse_year_month(params) do
      current_report =
        Revenue.find_report_for_period(store.reports, year_month.year, year_month.month)

      historical_data = generate_historical_data(store, year_month.month, year_month.year)
      area = Revenue.calculate_store_area(store)
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
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_group(user_id, group_id) do
    case Revenue.get_group(user_id, group_id) do
      {:error, :group_not_found} -> {:error, :group_not_found}
      {:ok, group} -> {:ok, group}
    end
  end

  defp get_building(user_id, group_id, building_id) do
    case Revenue.get_building(user_id, group_id, building_id) do
      nil -> {:error, :building_not_found}
      building -> {:ok, building}
    end
  end

  defp get_store(user_id, group_id, building_id, store_id) do
    case Revenue.get_store(user_id, group_id, building_id, store_id) do
      nil -> {:error, :store_not_found}
      store -> {:ok, store}
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

  defp handle_mount_error(socket, reason, group_id) do
    case reason do
      :group_not_found ->
        socket
        |> put_flash(:error, "Group not found")
        |> push_navigate(to: ~p"/app")

      :building_not_found ->
        socket
        |> put_flash(:error, "Building not found")
        |> push_navigate(to: ~p"/app/groups/#{group_id}")

      :store_not_found ->
        socket
        |> put_flash(:error, "Store not found")
        |> push_navigate(to: ~p"/app/groups/#{group_id}")
    end
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

defmodule AntoniaWeb.StoreLive do
  @moduledoc """
  LiveView for revenue detail management of a specific store.
  """
  use AntoniaWeb, :live_view

  import AntoniaWeb.SharedComponents

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
       timeline_events: [],
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
        # Set initial edited_revenue and note from current_report if it exists
        edited_revenue =
          if data.current_report && data.current_report.revenue do
            Decimal.to_float(data.current_report.revenue)
          else
            0
          end

        note = (data.current_report && data.current_report.note) || ""

        timeline_events = Report.timeline_events(data.current_report)

        {:noreply,
         assign(socket,
           group: data.group,
           building: data.building,
           store: data.store,
           year: data.year,
           month: data.month,
           current_report: data.current_report,
           historical_data: data.historical_data,
           edited_revenue: edited_revenue,
           note: note,
           timeline_events: timeline_events,
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
      # Preload email_logs with reports for timeline display
      store = Repo.preload(store, reports: [:email_logs])

      current_report =
        Revenue.find_report_for_period(store.reports, year_month.year, year_month.month)

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
         historical_data:
           format_historical_data_for_template(
             store.reports,
             year_month.month,
             year_month.year
           )
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
    Revenue.get_store(user_id, group_id, building_id, store_id)
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
  def handle_event("save_revenue", params, socket) do
    attrs = prepare_revenue_attrs(params, socket.assigns)

    case save_revenue_upsert(socket.assigns, attrs) do
      {:ok, _report} ->
        socket = update_socket_after_save(socket, attrs.note)
        {:noreply, put_flash(socket, :info, gettext("Revenue updated successfully"))}

      {:error, changeset} when is_struct(changeset) ->
        error_message = build_error_message(changeset)
        {:noreply, put_flash(socket, :error, error_message)}

      {:error, reason} when is_atom(reason) ->
        error_message = gettext("Failed to save revenue: %{reason}", reason: reason)
        {:noreply, put_flash(socket, :error, error_message)}
    end
  end

  defp prepare_revenue_attrs(params, assigns) do
    revenue_str = params["revenue"] || params[:revenue] || "0"
    note = params["note"] || params[:note] || assigns.note || ""

    %{
      revenue: revenue_str,
      note: note,
      year: assigns.year,
      month: assigns.month
    }
  end

  defp save_revenue_upsert(assigns, attrs) do
    existing_report =
      Revenue.find_report_for_period(assigns.store.reports || [], attrs.year, attrs.month)

    Revenue.upsert_report(
      assigns.user_id,
      assigns.group_id,
      assigns.building_id,
      assigns.store_id,
      existing_report,
      attrs
    )
  end

  defp update_socket_after_save(socket, note) do
    %{store_id: store_id, year: year, month: month} = socket.assigns

    store = reload_store_with_associations(store_id)
    current_report = Revenue.find_report_for_period(store.reports, year, month)

    socket
    |> assign(:store, store)
    |> assign(:current_report, current_report)
    |> assign(:edited_revenue, extract_revenue_float(current_report))
    |> assign(:note, note || "")
    |> assign(:timeline_events, Report.timeline_events(current_report))
    |> assign(
      :historical_data,
      format_historical_data_for_template(
        store.reports,
        month,
        year
      )
    )
    |> assign(:is_editing, false)
    |> assign(:selected_file, nil)
  end

  defp reload_store_with_associations(store_id) do
    Store
    |> Repo.get(store_id)
    |> Repo.preload(reports: [:email_logs])
    |> add_area_field()
  end

  defp add_area_field(store) do
    area = Revenue.calculate_store_area(store)
    Map.put(store, :area, area)
  end

  defp extract_revenue_float(nil), do: 0.0
  defp extract_revenue_float(report), do: Decimal.to_float(report.revenue || Decimal.new("0"))

  # Private helper functions

  defp format_historical_data_for_template(reports, selected_month, selected_year) do
    # Convert reports to template format
    # Group by year and get data for the selected month across different years
    current_year = Date.utc_today().year
    years = [current_year, current_year - 1, current_year - 2]

    historical_data =
      Enum.map(years, fn year ->
        # Find report for this year and selected month
        report = Revenue.find_report_for_period(reports, year, selected_month)

        revenue =
          if report && report.revenue do
            Decimal.to_float(report.revenue)
          else
            0.0
          end

        %{year: year, revenue: revenue, is_current: year == selected_year}
      end)

    Enum.sort_by(historical_data, & &1.year, :desc)
  end

  defp format_currency(amount, currency) when is_number(amount) do
    currency = currency || "EUR"
    amount = :erlang.float_to_binary(amount * 1.0, decimals: 2)
    amount = String.replace(amount, ~r/\B(?=(\d{3})+(?!\d))/, ",")

    symbol =
      case currency do
        "EUR" -> "€"
        "AUD" -> "A$"
        "USD" -> "$"
        _ -> currency
      end

    "#{symbol}#{amount}"
  end

  defp format_currency(amount, _) when is_number(amount), do: format_currency(amount, "EUR")
  defp format_currency(_, _), do: "€0"

  defp month_name(month) do
    month_names = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ]

    Enum.at(month_names, month - 1, "Unknown")
  end

  defp build_error_message(changeset) do
    case changeset.errors do
      [] ->
        gettext("Failed to update revenue")

      errors ->
        error_details =
          Enum.map_join(errors, ", ", fn {field, {message, _}} ->
            "#{field}: #{message}"
          end)

        gettext("Failed to update revenue: %{errors}", errors: error_details)
    end
  end

  defp format_timestamp(%NaiveDateTime{} = datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  defp format_timestamp(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  defp format_timestamp(_), do: ""
end

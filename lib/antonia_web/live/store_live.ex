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

        timeline_events = generate_timeline_events(data.current_report)

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

      historical_data = Revenue.generate_historical_data(store, year_month.month, year_month.year)
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
             historical_data,
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
      note: note
    } = socket.assigns

    case upsert_report_for_period(store, year, month, revenue, note) do
      {:ok, _updated_report} ->
        # Reload store with updated reports and email_logs
        store = Repo.get(Store, store.id)
        store = Repo.preload(store, reports: [:email_logs])
        # Re-add the area field
        area = Revenue.calculate_store_area(store)
        store_with_area = Map.put(store, :area, area)

        # Find the updated report from the reloaded store to ensure we have fresh data
        current_report = Revenue.find_report_for_period(store_with_area.reports, year, month)

        historical_data = Revenue.generate_historical_data(store_with_area, month, year)

        # Update edited_revenue to reflect the new value
        updated_revenue =
          if current_report && current_report.revenue do
            Decimal.to_float(current_report.revenue)
          else
            0
          end

        timeline_events = generate_timeline_events(current_report)

        socket =
          socket
          |> assign(:store, store_with_area)
          |> assign(:current_report, current_report)
          |> assign(:edited_revenue, updated_revenue)
          |> assign(:note, note)
          |> assign(:timeline_events, timeline_events)
          |> assign(
            :historical_data,
            format_historical_data_for_template(historical_data, month, year)
          )
          |> assign(:is_editing, false)
          |> assign(:selected_file, nil)
          |> put_flash(:info, gettext("Revenue updated successfully"))

        {:noreply, socket}

      {:error, changeset} ->
        error_message = build_error_message(changeset)
        {:noreply, put_flash(socket, :error, error_message)}
    end
  end

  # Private helper functions

  defp upsert_report_for_period(store, year, month, revenue, note) do
    period_start = Date.new!(year, month, 1)
    period_end = Date.end_of_month(period_start)

    # Check if report exists for this period
    existing_report =
      Revenue.find_report_for_period(store.reports, year, month)

    # Convert float to Decimal - Decimal.new/1 works with strings or integers
    # For floats, we convert to string first to avoid precision issues
    revenue_decimal =
      case revenue do
        revenue when is_float(revenue) ->
          # Convert float to string with sufficient precision, then to Decimal
          revenue |> :erlang.float_to_binary(decimals: 2) |> Decimal.new()

        revenue when is_integer(revenue) ->
          Decimal.new(revenue)

        revenue when is_binary(revenue) ->
          Decimal.new(revenue)

        %Decimal{} = revenue ->
          revenue

        _ ->
          Decimal.new("0")
      end

    report_params = %{
      store_id: store.id,
      revenue: revenue_decimal,
      period_start: period_start,
      period_end: period_end,
      currency: "AUD",
      status: if(existing_report, do: existing_report.status, else: :pending),
      note: note
    }

    if existing_report do
      # Update existing report - only update revenue and note, preserve status
      existing_report
      |> Report.changeset(report_params)
      |> Repo.update()
    else
      # Create new report
      %Report{}
      |> Report.changeset(report_params)
      |> Repo.insert()
    end
  end

  defp format_historical_data_for_template(historical_data, selected_month, selected_year) do
    # Convert context module's historical data format to template format
    # Group by year and get data for the selected month across different years
    current_year = Date.utc_today().year
    years = [current_year, current_year - 1, current_year - 2]

    historical_data =
      Enum.map(years, fn year ->
        # Find data for this year and selected month
        month_data =
          Enum.find(historical_data, fn data ->
            data.year == year && data.month == selected_month
          end)

        revenue =
          if month_data && month_data.revenue do
            Decimal.to_float(month_data.revenue)
          else
            0
          end

        %{year: year, revenue: revenue, is_current: year == selected_year}
      end)

    Enum.sort_by(historical_data, & &1.year, :desc)
  end

  defp format_currency(amount, currency) when is_number(amount) do
    currency = currency || "AUD"
    amount = :erlang.float_to_binary(amount * 1.0, decimals: 0)
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

  defp format_currency(amount, _) when is_number(amount), do: format_currency(amount, "AUD")
  defp format_currency(_, _), do: "A$0"

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

  defp generate_timeline_events(nil), do: []

  defp generate_timeline_events(report) do
    report
    |> build_report_events()
    |> add_email_events(report)
    |> sort_events_by_timestamp()
  end

  defp build_report_events(report) do
    base_events = [build_created_event(report)]

    if report_was_updated?(report) do
      base_events ++ [build_updated_event(report)]
    else
      base_events
    end
  end

  defp build_created_event(report) do
    %{
      type: :created,
      title: gettext("Report created"),
      description: gettext("Revenue report was created"),
      timestamp: report.inserted_at,
      is_complete: true
    }
  end

  defp build_updated_event(report) do
    %{
      type: :updated,
      title: gettext("Report updated"),
      description: gettext("Revenue information was modified"),
      timestamp: report.updated_at,
      is_complete: true
    }
  end

  defp report_was_updated?(report) do
    NaiveDateTime.compare(report.inserted_at, report.updated_at) != :eq
  end

  defp add_email_events(events, report) do
    if email_logs_available?(report) do
      email_events = build_email_events(report.email_logs)
      events ++ email_events
    else
      events
    end
  end

  defp email_logs_available?(report) do
    Ecto.assoc_loaded?(report.email_logs) && report.email_logs
  end

  defp build_email_events(email_logs) do
    email_logs
    |> Enum.filter(fn log -> log.status == :sent && log.sent_at end)
    |> Enum.map(&build_email_event/1)
  end

  defp build_email_event(log) do
    email_type_label = get_email_type_label(log.email_type)

    %{
      type: :email,
      title: gettext("Email sent"),
      description: "#{email_type_label} - #{log.recipient_email}",
      timestamp: log.sent_at,
      is_complete: true
    }
  end

  defp get_email_type_label(:monthly_reminder), do: gettext("Monthly reminder")
  defp get_email_type_label(:overdue_reminder), do: gettext("Overdue reminder")
  defp get_email_type_label(:initial_request), do: gettext("Initial request")
  defp get_email_type_label(email_type), do: to_string(email_type)

  defp sort_events_by_timestamp(events) do
    Enum.sort_by(events, &timestamp_to_unix/1, :asc)
  end

  defp timestamp_to_unix(event) do
    case event.timestamp do
      %NaiveDateTime{} = dt ->
        dt |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()

      %DateTime{} = dt ->
        DateTime.to_unix(dt)

      _ ->
        0
    end
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

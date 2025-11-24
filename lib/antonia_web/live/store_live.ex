defmodule AntoniaWeb.StoreLive do
  @moduledoc """
  LiveView for revenue detail management of a specific store.
  """
  use AntoniaWeb, :live_view

  import AntoniaWeb.SharedComponents

  import AntoniaWeb.DisplayHelpers,
    only: [format_currency: 2, format_timestamp: 1, build_error_message: 2, format_number_for_input: 1]

  alias Antonia.MailerWorker
  alias Antonia.Repo
  alias Antonia.Revenue
  alias Antonia.Revenue.Attachment
  alias Antonia.Revenue.Report
  alias Antonia.Revenue.Store
  alias Antonia.Services.S3

  @impl Phoenix.LiveView
  def mount(
        %{"id" => group_id, "building_id" => building_id, "store_id" => store_id} = params,
        %{"auth" => auth},
        socket
      ) do
    user_id = auth.uid
    send(self(), {:fetch_store_data, user_id, group_id, building_id, store_id, params})

    {:ok,
     socket
     |> allow_upload(:attachments,
       accept: ~w(.jpg .jpeg .png .pdf .doc .docx .xlsx .txt),
       max_entries: 10,
       auto_upload: true,
       external: &S3.presign_upload/2
     )
     |> assign(
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
       sending_email?: false
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
      # Preload email_logs and attachments with reports for timeline display
      store = Repo.preload(store, reports: [:email_logs, :attachments])

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
  def handle_event("send_report_email", _params, socket) do
    socket = assign(socket, :sending_email?, true)

    result =
      case socket.assigns.current_report do
        nil ->
          # Create a new report if it doesn't exist
          create_report_and_send_email(socket)

        report ->
          # Use existing report
          send_email_for_report(socket, report)
      end

    case result do
      {:ok, updated_socket} ->
        {:noreply, updated_socket}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:sending_email?, false)
         |> put_flash(:error, gettext("Failed to send email: %{reason}", reason: reason))}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("save_revenue", params, socket) do
    attrs = prepare_revenue_attrs(params, socket.assigns)

    case save_revenue_upsert(socket.assigns, attrs) do
      {:ok, report} ->
        # Save attachments if any were uploaded
        save_attachments(socket, report)
        socket = update_socket_after_save(socket, attrs.note)
        {:noreply, put_flash(socket, :info, gettext("Revenue updated successfully"))}

      {:error, changeset} when is_struct(changeset) ->
        error_message = build_error_message(changeset, gettext("Failed to update revenue"))
        {:noreply, put_flash(socket, :error, error_message)}

      {:error, reason} when is_atom(reason) ->
        error_message = gettext("Failed to save revenue: %{reason}", reason: reason)
        {:noreply, put_flash(socket, :error, error_message)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :attachments, ref)}
  rescue
    ArgumentError ->
      # Entry might have already been consumed or doesn't exist
      {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("view_attachment", %{"id" => attachment_id}, socket) do
    attachment = Repo.get(Attachment, attachment_id)

    case attachment && S3.presign_read(attachment.s3_key) do
      {:ok, url} ->
        {:noreply, push_event(socket, "open_url", %{url: url})}

      _ ->
        {:noreply, put_flash(socket, :error, gettext("Failed to generate attachment URL"))}
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
  end

  defp reload_store_with_associations(store_id) do
    Store
    |> Repo.get(store_id)
    |> Repo.preload(reports: [:email_logs, :attachments])
    |> add_area_field()
  end

  defp add_area_field(store) do
    area = Revenue.calculate_store_area(store)
    Map.put(store, :area, area)
  end

  defp extract_revenue_float(nil), do: 0.0
  defp extract_revenue_float(report), do: Decimal.to_float(report.revenue || Decimal.new("0"))

  # Attachment helpers

  defp extract_file_info(%{key: s3_key}, %Phoenix.LiveView.UploadEntry{
         progress: progress,
         client_name: client_name,
         client_type: client_type,
         client_size: client_size
       }) do
    case progress do
      100 ->
        {:ok,
         %{
           s3_key: s3_key,
           filename: client_name,
           file_type: client_type,
           file_size: client_size
         }}

      _ ->
        {:error, :upload_not_finished}
    end
  end

  defp save_attachments(socket, report) do
    attachments =
      consume_uploaded_entries(socket, :attachments, fn entry, %{key: s3_key} ->
        extract_file_info(%{key: s3_key}, entry)
      end)

    Enum.each(attachments, fn
      {:ok, attrs} ->
        attrs_with_report = Map.put(attrs, :report_id, report.id)
        changeset = Attachment.changeset(%Attachment{}, attrs_with_report)

        case Repo.insert(changeset) do
          {:ok, _attachment} -> :ok
          {:error, _changeset} -> :ok
        end

      {:error, _} ->
        :ok
    end)
  end

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

  defp create_report_and_send_email(socket) do
    %{
      year: year,
      month: month,
      user_id: user_id,
      group_id: group_id,
      building_id: building_id,
      store_id: store_id
    } =
      socket.assigns

    # Build report attributes with defaults
    attrs = %{
      revenue: "0",
      note: "",
      year: year,
      month: month,
      status: "pending"
    }

    case Revenue.upsert_report(user_id, group_id, building_id, store_id, nil, attrs) do
      {:ok, report} ->
        send_email_for_report(socket, report)

      {:error, changeset} ->
        error_message = build_error_message(changeset, gettext("Failed to create report"))
        {:error, error_message}
    end
  end

  defp send_email_for_report(socket, report) do
    # Schedule the email using MailerWorker
    %{report_id: report.id, email_type: "monthly_reminder"}
    |> MailerWorker.new()
    |> Oban.insert()

    # Reload store data to get updated report with email_logs
    store = reload_store_with_associations(socket.assigns.store_id)

    current_report =
      Revenue.find_report_for_period(store.reports, socket.assigns.year, socket.assigns.month)

    updated_timeline = Report.timeline_events(current_report)

    updated_socket =
      socket
      |> assign(:sending_email?, false)
      |> assign(:store, store)
      |> assign(:current_report, current_report)
      |> assign(:timeline_events, updated_timeline)
      |> put_flash(
        :info,
        gettext("Email sent to %{email}", email: socket.assigns.store.email)
      )

    {:ok, updated_socket}
  end
end

defmodule AntoniaWeb.ReportSubmissionLive do
  @moduledoc """
  Public LiveView for submitting revenue reports via secure token links.
  No authentication required.
  """
  use AntoniaWeb, :live_view

  import AntoniaWeb.DisplayHelpers,
    only: [format_currency: 2, format_date: 1, build_error_message: 2, format_number_for_input: 1]

  alias Antonia.Repo
  alias Antonia.Revenue
  alias Antonia.Revenue.Attachment
  alias Antonia.Revenue.EmailLog
  alias Antonia.Services.S3

  @impl Phoenix.LiveView
  def mount(%{"token" => token}, _session, socket) do
    case load_and_validate_token(token) do
      {:ok, email_log, report} ->
        # Get user_id from the group's created_by_user_id for S3 uploads
        user_id = report.store.building.group.created_by_user_id

        {:ok,
         socket
         |> allow_upload(:attachments,
           accept: ~w(.jpg .jpeg .png .pdf .doc .docx .xlsx .txt),
           max_entries: 10,
           auto_upload: true,
           external: &S3.presign_upload/2
         )
         |> assign(
           error: nil,
           email_log: email_log,
           report: report,
           submitted: false,
           revenue: extract_revenue_float(report),
           note: report.note || "",
           user_id: user_id
         )}

      {:error, :token_not_found} ->
        {:ok,
         assign(socket,
           error: :token_not_found,
           email_log: nil,
           report: nil,
           submitted: false
         )}

      {:error, :token_invalid, email_log} ->
        {:ok,
         assign(socket,
           error: :token_invalid,
           email_log: email_log,
           report: email_log.report,
           submitted: false
         )}
    end
  end

  defp load_and_validate_token(token) do
    case EmailLog.find_by_token(token) do
      nil ->
        {:error, :token_not_found}

      email_log ->
        if EmailLog.valid?(email_log) do
          mark_as_accessed_if_needed(email_log)
          report = Repo.preload(email_log.report, store: [building: :group])
          {:ok, email_log, report}
        else
          {:error, :token_invalid, email_log}
        end
    end
  end

  defp mark_as_accessed_if_needed(email_log) do
    if is_nil(email_log.accessed_at) do
      email_log
      |> EmailLog.mark_accessed()
      |> Repo.update()
    end
  end

  @impl Phoenix.LiveView
  def handle_event("update_revenue", %{"revenue" => revenue_str}, socket) do
    revenue =
      try do
        String.to_float(revenue_str || "0")
      rescue
        _ -> 0
      end

    {:noreply, assign(socket, :revenue, revenue)}
  end

  @impl Phoenix.LiveView
  def handle_event("update_note", %{"note" => note}, socket) do
    {:noreply, assign(socket, :note, note)}
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
  def handle_event("submit_report", params, socket) do
    case socket.assigns do
      %{error: nil, report: report, email_log: email_log} ->
        # Get revenue from params (form submission) or socket assigns (real-time updates)
        revenue = params["revenue"] || socket.assigns.revenue || 0
        note = params["note"] || socket.assigns.note || ""
        submit_report(socket, report, revenue, note, email_log)

      _ ->
        {:noreply, put_flash(socket, :error, gettext("Invalid submission link"))}
    end
  end

  defp submit_report(socket, report, revenue, note, email_log) do
    # Revenue can be a string (from form) or a number (from socket assigns)
    revenue_str =
      if is_binary(revenue) do
        revenue
      else
        to_string(revenue)
      end

    attrs = %{
      revenue: revenue_str,
      note: note
    }

    case Revenue.update_report_via_token(report, attrs) do
      {:ok, updated_report} ->
        # Save attachments if any were uploaded
        save_attachments(socket, updated_report)
        # Mark as submitted and extend expiry (ignore errors here as report is already updated)
        _ = mark_submitted_and_extend_expiry(email_log)

        {:noreply,
         assign(socket,
           submitted: true,
           report: updated_report
         )}

      {:error, changeset} ->
        error_message = build_error_message(changeset, gettext("Failed to submit report"))
        {:noreply, put_flash(socket, :error, error_message)}
    end
  end

  defp mark_submitted_and_extend_expiry(email_log) do
    updated_expires_at =
      if email_log.expires_at do
        DateTime.add(email_log.expires_at, 30, :minute)
      else
        nil
      end

    email_log
    |> EmailLog.mark_submitted()
    |> Ecto.Changeset.change(expires_at: updated_expires_at)
    |> Repo.update()
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
end

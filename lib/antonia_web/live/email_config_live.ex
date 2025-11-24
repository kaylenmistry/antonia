defmodule AntoniaWeb.EmailConfigLive do
  @moduledoc """
  LiveView for configuring email settings for a group.
  """
  use AntoniaWeb, :live_view

  import AntoniaWeb.SharedComponents
  import AntoniaWeb.DisplayHelpers, only: [format_date: 1]

  alias Antonia.Revenue
  alias Antonia.Services.S3

  @impl Phoenix.LiveView
  def mount(%{"id" => group_id}, %{"auth" => auth}, socket) do
    user_id = auth.uid

    case Revenue.get_group(user_id, group_id) do
      {:ok, group} ->
        {:ok,
         socket
         |> assign(group_id: group_id)
         |> allow_upload(:logo,
           accept: ~w(.jpg .jpeg .png .svg),
           max_entries: 1,
           auto_upload: true,
           external: fn entry, socket ->
             S3.presign_logo_upload(entry, socket)
           end
         )
         |> assign(
           group: group,
           user_id: user_id,
           group_id: group_id,
           company_name: group.email_company_name || group.name,
           logo_url: group.email_logo_url || "https://rutter.at/themes/rutter/img/rutter-logo.png",
           preview_logo_url: group.email_logo_url || "https://rutter.at/themes/rutter/img/rutter-logo.png",
           saving?: false
         )}

      {:error, :group_not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Group not found"))
         |> push_navigate(to: ~p"/app")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("update_company_name", %{"company_name" => company_name}, socket) do
    {:noreply, assign(socket, company_name: company_name)}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :logo, ref)}
  rescue
    ArgumentError ->
      {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("save", _params, socket) do
    socket = assign(socket, saving?: true)

    attrs = %{
      email_company_name: socket.assigns.company_name,
      email_logo_url: socket.assigns.logo_url
    }

    case Revenue.update_group(socket.assigns.user_id, socket.assigns.group_id, attrs) do
      {:ok, updated_group} ->
        {:noreply,
         socket
         |> assign(
           group: updated_group,
           saving?: false,
           logo_url: updated_group.email_logo_url || socket.assigns.logo_url,
           preview_logo_url: updated_group.email_logo_url || socket.assigns.logo_url
         )
         |> put_flash(:info, gettext("Email configuration saved successfully"))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(saving?: false)
         |> put_flash(:error, gettext("Failed to save email configuration"))}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("logo_uploaded", %{"ref" => ref}, socket) do
    # Find the completed entry
    entry = Enum.find(socket.assigns.uploads.logo.entries, &(&1.ref == ref))

    if entry && entry.progress == 100 do
      # Consume the uploaded entry to get the S3 key
      uploaded_entries = consume_uploaded_entries(socket, :logo, fn _entry, %{key: s3_key} ->
        {:ok, s3_key}
      end)

      case uploaded_entries do
        [{:ok, s3_key} | _] ->
          # Get presigned read URL for the uploaded logo
          case S3.presign_read(s3_key) do
            {:ok, url} ->
              {:noreply,
               socket
               |> assign(preview_logo_url: url, logo_url: s3_key)}

            {:error, _error} ->
              {:noreply,
               socket
               |> put_flash(:error, gettext("Failed to load uploaded logo"))}
          end

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

end

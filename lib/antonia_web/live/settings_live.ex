defmodule AntoniaWeb.SettingsLive do
  @moduledoc """
  LiveView for group settings including email configuration.
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
           user: auth.info,
           user_id: user_id,
           group_id: group_id,
           group_name: group.name,
           company_name: group.email_company_name || group.name,
           logo_url: group.email_logo_url,
           preview_logo_url: get_preview_logo_url(group.email_logo_url),
           saving_group_name?: false,
           saving_email?: false
         )}

      {:error, :group_not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Group not found"))
         |> push_navigate(to: ~p"/app")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :logo, ref)}
  rescue
    ArgumentError ->
      {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("save_group_name", params, socket) do
    socket = assign(socket, saving_group_name?: true)

    # Read value from form params to ensure we get the latest value
    group_name = params["group_name"] || socket.assigns.group_name

    attrs = %{
      name: group_name
    }

    case Revenue.update_group(socket.assigns.user_id, socket.assigns.group_id, attrs) do
      {:ok, updated_group} ->
        {:noreply,
         socket
         |> assign(
           group: updated_group,
           group_name: updated_group.name,
           saving_group_name?: false
         )
         |> put_flash(:info, gettext("Group name saved successfully"))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(saving_group_name?: false)
         |> put_flash(:error, gettext("Failed to save group name"))}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("save_email_config", params, socket) do
    socket = assign(socket, saving_email?: true)

    # Read values from form params to ensure we get the latest values
    company_name = params["company_name"] || socket.assigns.company_name

    attrs = %{
      email_company_name: company_name,
      email_logo_url: socket.assigns.logo_url
    }

    case Revenue.update_group(socket.assigns.user_id, socket.assigns.group_id, attrs) do
      {:ok, updated_group} ->
        preview_url =
          get_preview_logo_url(updated_group.email_logo_url || socket.assigns.logo_url)

        {:noreply,
         socket
         |> assign(
           group: updated_group,
           saving_email?: false,
           company_name: updated_group.email_company_name || updated_group.name,
           logo_url: updated_group.email_logo_url || socket.assigns.logo_url,
           preview_logo_url: preview_url
         )
         |> put_flash(:info, gettext("Email configuration saved successfully"))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(saving_email?: false)
         |> put_flash(:error, gettext("Failed to save email configuration"))}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("logo_uploaded", %{"ref" => ref}, socket) do
    # Find the completed entry and consume it
    entry = Enum.find(socket.assigns.uploads.logo.entries, &(&1.ref == ref))

    if entry && entry.progress == 100 do
      uploaded_entries =
        consume_uploaded_entries(socket, :logo, fn _entry, %{key: s3_key} ->
          {:ok, s3_key}
        end)

      case uploaded_entries do
        [{:ok, s3_key} | _] ->
          preview_url = get_preview_logo_url(s3_key)
          {:noreply, assign(socket, preview_logo_url: preview_url, logo_url: s3_key)}

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Helper to get preview logo URL (presigned if S3 key, otherwise use as-is or default)
  defp get_preview_logo_url(nil), do: "https://rutter.at/themes/rutter/img/rutter-logo.png"

  defp get_preview_logo_url(logo_url) when is_binary(logo_url) do
    if String.starts_with?(logo_url, "private/") do
      case S3.presign_read(logo_url) do
        {:ok, url} -> url
        {:error, _} -> "https://rutter.at/themes/rutter/img/rutter-logo.png"
      end
    else
      logo_url
    end
  end

  defp get_preview_logo_url(_), do: "https://rutter.at/themes/rutter/img/rutter-logo.png"
end

defmodule AntoniaWeb.GroupsLive do
  @moduledoc """
  LiveView for managing groups.
  """
  use AntoniaWeb, :live_view

  import AntoniaWeb.SharedComponents
  import AntoniaWeb.FormHelpers, only: [format_params: 1]

  alias Antonia.Revenue

  @impl Phoenix.LiveView
  def mount(_params, %{"auth" => auth}, socket) do
    user_id = auth.uid
    send(self(), {:fetch_groups, user_id})

    {:ok,
     assign(socket,
       user: auth.info,
       user_id: user_id,
       groups: [],
       form: to_form(Revenue.change_group())
     )}
  end

  @impl Phoenix.LiveView
  def handle_info({:fetch_groups, user_id}, socket) do
    groups = Revenue.list_groups(user_id)
    {:noreply, assign(socket, groups: groups)}
  end

  @impl Phoenix.LiveView
  def handle_event("create_group", %{"group" => group_params}, socket) do
    case Revenue.create_group(socket.assigns.user_id, format_params(group_params)) do
      {:ok, group} ->
        socket =
          socket
          |> put_flash(:info, gettext("Created group") <> " '" <> group.name <> "'")
          |> assign(groups: [group | socket.assigns.groups])
          |> assign(form: to_form(Revenue.change_group()))

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("select_group", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/app/groups/#{id}")}
  end

  @impl Phoenix.LiveView
  def handle_event("dialog_closed", _params, socket) do
    # Reset form when dialog closes
    socket = assign(socket, :form, to_form(Revenue.change_group()))
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("open_add_group_modal", _params, socket) do
    {:noreply, socket}
  end
end

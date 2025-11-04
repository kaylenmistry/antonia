defmodule AntoniaWeb.ReportingLive do
  @moduledoc "LiveView for reporting dashboard of a specific group"
  use AntoniaWeb, :live_view

  import AntoniaWeb.FormHelpers, only: [format_params: 1]
  import AntoniaWeb.SharedComponents

  alias Antonia.Revenue
  alias Antonia.Revenue.Building

  @impl Phoenix.LiveView
  def mount(%{"id" => group_id}, %{"auth" => auth}, socket) do
    user_id = auth.uid

    case Revenue.get_group(user_id, group_id) do
      {:ok, group} ->
        send(self(), {:fetch_data, user_id, group_id})

        {:ok,
         socket
         |> assign(:group, group)
         |> assign(:buildings, nil)
         |> assign(:dashboard_stats, nil)
         |> assign(:form, to_form(Building.changeset(%Building{}, %{group_id: group_id})))
         |> assign(:user, auth.info)
         |> assign(:user_id, user_id)}

      {:error, :group_not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Group not found"))
         |> push_navigate(to: ~p"/app")}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:fetch_data, user_id, group_id}, socket) do
    buildings = Revenue.list_buildings_with_stats(user_id, group_id)

    dashboard_stats =
      case Revenue.get_group_dashboard_stats(user_id, group_id) do
        {:ok, stats} -> stats
        {:error, _} -> %{buildings_count: 0, stores_count: 0, reported_count: 0, pending_count: 0}
      end

    {:noreply,
     socket
     |> assign(:buildings, buildings)
     |> assign(:dashboard_stats, dashboard_stats)}
  end

  @impl Phoenix.LiveView
  def handle_event("dialog_closed", _, socket) do
    form = to_form(Building.changeset(%Building{}, %{group_id: socket.assigns.group.id}))
    {:noreply, assign(socket, :form, form)}
  end

  @impl Phoenix.LiveView
  def handle_event("create_building", %{"building" => params}, socket) do
    user_id = socket.assigns.user_id
    formatted_params = format_params(params)

    case Revenue.create_building(user_id, socket.assigns.group.id, formatted_params) do
      {:ok, building} ->
        # Reload buildings and stats to include the new one
        send(self(), {:fetch_data, user_id, socket.assigns.group.id})

        socket =
          socket
          |> put_flash(:info, gettext("Created building") <> " '" <> building.name <> "'")
          |> assign(
            :form,
            to_form(Building.changeset(%Building{}, %{group_id: socket.assigns.group.id}))
          )
          |> push_event("close-dialog", %{id: "add-building-dialog"})

        {:noreply, socket}

      {:error, changeset} when is_struct(changeset) ->
        {:noreply, assign(socket, :form, to_form(changeset))}

      {:error, :group_not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Group not found"))
         |> push_navigate(to: ~p"/app")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("navigate_to_building", %{"building_id" => building_id}, socket) do
    {:noreply,
     push_navigate(socket,
       to: ~p"/app/groups/#{socket.assigns.group.id}/buildings/#{building_id}"
     )}
  end
end

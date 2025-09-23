defmodule AntoniaWeb.BusinessLive do
  @moduledoc """
  LiveView for managing buildings within a group.
  """
  use AntoniaWeb, :live_view

  import AntoniaWeb.SharedComponents
  import Ecto.Query

  alias Antonia.Repo
  alias Antonia.Revenue.Building
  alias Antonia.Revenue.Store

  @impl Phoenix.LiveView
  def mount(%{"id" => group_id, "building_id" => building_id}, _session, socket) do
    building = Repo.get(Building, building_id)

    if building && building.group_id == group_id do
      stores = Repo.all(from s in Store, where: s.building_id == ^building_id)

      {:ok,
       socket
       |> assign(:group_id, group_id)
       |> assign(:building, building)
       |> assign(:stores, stores)
       |> assign(:show_form, false)
       |> assign(:changeset, Store.changeset(%Store{}, %{building_id: building_id}))}
    else
      {:ok,
       socket
       |> put_flash(:error, gettext("Building not found"))
       |> push_navigate(to: ~p"/app/groups/#{group_id}")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("close-dialog", _, socket) do
    changeset = Store.changeset(%Store{}, %{building_id: socket.assigns.building.id})
    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl Phoenix.LiveView
  def handle_event("open_add_shop_modal", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"store" => params}, socket) do
    # Use all fields that exist in the current schema
    store_params = Map.take(params, ["name", "email", "area"])
    store_params = Map.put(store_params, "building_id", socket.assigns.building.id)

    case %Store{}
         |> Store.changeset(store_params)
         |> Repo.insert() do
      {:ok, _store} ->
        stores =
          Repo.all(from s in Store, where: s.building_id == ^socket.assigns.building.id)

        {:noreply,
         socket
         |> assign(:stores, stores)
         |> assign(
           :changeset,
           Store.changeset(%Store{}, %{building_id: socket.assigns.building.id})
         )
         |> put_flash(:info, gettext("Shop created successfully!"))}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"store" => params}, socket) do
    # Validate all fields that exist in the current schema
    store_params = Map.take(params, ["name", "email", "area"])
    store_params = Map.put(store_params, "building_id", socket.assigns.building.id)

    changeset =
      %Store{}
      |> Store.changeset(store_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end
end

defmodule AntoniaWeb.GroupLive do
  @moduledoc """
  LiveView for managing groups.
  """
  use AntoniaWeb, :live_view

  import Ecto.Query

  alias Antonia.Repo
  alias Antonia.Revenue.ShoppingCentre
  alias Antonia.Revenue.Store

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    shopping_centre = Repo.get(ShoppingCentre, id)

    if shopping_centre do
      stores = Repo.all(from s in Store, where: s.shopping_centre_id == ^id)

      {:ok,
       socket
       |> assign(:shopping_centre, shopping_centre)
       |> assign(:stores, stores)
       |> assign(:show_form, false)
       |> assign(:changeset, Store.changeset(%Store{}, %{shopping_centre_id: id}))}
    else
      {:ok,
       socket
       |> put_flash(:error, "Shopping centre not found")
       |> push_navigate(to: ~p"/app")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("show-add-form", _, socket) do
    {:noreply, assign(socket, :show_form, true)}
  end

  @impl Phoenix.LiveView
  def handle_event("hide-add-form", _, socket) do
    {:noreply, assign(socket, :show_form, false)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"store" => params}, socket) do
    case %Store{}
         |> Store.changeset(params)
         |> Repo.insert() do
      {:ok, _store} ->
        stores =
          Repo.all(
            from s in Store, where: s.shopping_centre_id == ^socket.assigns.shopping_centre.id
          )

        {:noreply,
         socket
         |> assign(:stores, stores)
         |> assign(:show_form, false)
         |> assign(
           :changeset,
           Store.changeset(%Store{}, %{shopping_centre_id: socket.assigns.shopping_centre.id})
         )
         |> put_flash(:info, "Store created successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"store" => params}, socket) do
    changeset =
      %Store{}
      |> Store.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end
end

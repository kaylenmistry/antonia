defmodule AntoniaWeb.AppLive do
  use AntoniaWeb, :live_view

  alias Antonia.Repo
  alias Antonia.Revenue.ShoppingCentre

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    shopping_centres = Repo.all(ShoppingCentre)

    {:ok,
     socket
     |> assign(:shopping_centres, shopping_centres)
     |> assign(:show_form, false)
     |> assign(:changeset, ShoppingCentre.changeset(%ShoppingCentre{}, %{}))}
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
  def handle_event("save", %{"shopping_centre" => params}, socket) do
    case %ShoppingCentre{}
         |> ShoppingCentre.changeset(params)
         |> Repo.insert() do
      {:ok, _shopping_centre} ->
        shopping_centres = Repo.all(ShoppingCentre)

        {:noreply,
         socket
         |> assign(:shopping_centres, shopping_centres)
         |> assign(:show_form, false)
         |> assign(:changeset, ShoppingCentre.changeset(%ShoppingCentre{}, %{}))
         |> put_flash(:info, "Shopping centre created successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"shopping_centre" => params}, socket) do
    changeset =
      %ShoppingCentre{}
      |> ShoppingCentre.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end
end

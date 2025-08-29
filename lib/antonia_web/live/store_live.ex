defmodule AntoniaWeb.StoreLive do
  use AntoniaWeb, :live_view

  import Ecto.Query

  alias Antonia.Repo

  alias Antonia.Revenue.Report
  alias Antonia.Revenue.ShoppingCentre
  alias Antonia.Revenue.Store

  @impl Phoenix.LiveView
  def mount(%{"id" => group_id, "store_id" => store_id}, _session, socket) do
    shopping_centre = Repo.get(ShoppingCentre, group_id)
    store = Repo.get(Store, store_id)

    if shopping_centre && store && store.shopping_centre_id == group_id do
      reports =
        Repo.all(
          from r in Report, where: r.store_id == ^store_id, order_by: [desc: r.inserted_at]
        )

      {:ok,
       socket
       |> assign(:shopping_centre, shopping_centre)
       |> assign(:store, store)
       |> assign(:reports, reports)
       |> assign(:show_form, false)
       |> assign(:changeset, Report.changeset(%Report{}, %{store_id: store_id}))}
    else
      {:ok,
       socket
       |> put_flash(:error, "Store not found")
       |> push_navigate(to: ~p"/app/groups/#{group_id}")}
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
  def handle_event("save", %{"report" => params}, socket) do
    case %Report{}
         |> Report.changeset(params)
         |> Repo.insert() do
      {:ok, _report} ->
        reports =
          Repo.all(
            from r in Report,
              where: r.store_id == ^socket.assigns.store.id,
              order_by: [desc: r.inserted_at]
          )

        {:noreply,
         socket
         |> assign(:reports, reports)
         |> assign(:show_form, false)
         |> assign(:changeset, Report.changeset(%Report{}, %{store_id: socket.assigns.store.id}))
         |> put_flash(:info, "Report created successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"report" => params}, socket) do
    changeset =
      %Report{}
      |> Report.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end
end

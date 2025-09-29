defmodule AntoniaWeb.GroupsLive do
  @moduledoc """
  LiveView for managing groups.
  """
  use AntoniaWeb, :live_view

  import AntoniaWeb.SharedComponents

  alias Antonia.Repo
  alias Antonia.Revenue.Group

  @impl Phoenix.LiveView
  def mount(_params, %{"auth" => auth}, socket) do
    groups = Repo.all(Group)

    socket =
      socket
      |> assign(:groups, groups)
      |> assign(:form, to_form(Group.changeset(%Group{}, %{})))
      |> assign(:user, auth.info)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("create_group", %{"group" => group_params}, socket) do
    result = %Group{} |> Group.changeset(group_params) |> Repo.insert()

    case result do
      {:ok, group} ->
        socket =
          socket
          |> put_flash(:info, gettext("Created group") <> " '" <> group.name <> "'")
          |> push_navigate(to: ~p"/app/groups/#{group.id}")

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
    socket = socket
    socket = assign(socket, :form, to_form(Group.changeset(%Group{}, %{})))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("open_add_group_modal", _params, socket) do
    {:noreply, socket}
  end
end

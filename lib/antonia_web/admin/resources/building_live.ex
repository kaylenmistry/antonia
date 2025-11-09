defmodule AntoniaWeb.Admin.Resources.BuildingLive do
  @moduledoc """
  LiveResource for managing buildings in the admin panel.
  """
  use Backpex.LiveResource,
    layout: {AntoniaWeb.Layouts, :admin},
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: Antonia.Revenue.Building,
      repo: Antonia.Repo,
      update_changeset: &Antonia.Revenue.Building.changeset/3,
      create_changeset: &Antonia.Revenue.Building.changeset/3
    ],
    pubsub: [server: Antonia.PubSub]

  @impl Backpex.LiveResource
  def singular_name, do: "Building"

  @impl Backpex.LiveResource
  def plural_name, do: "Buildings"

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Name"
      },
      address: %{
        module: Backpex.Fields.Text,
        label: "Address"
      },
      group_id: %{
        module: Backpex.Fields.Text,
        label: "Group ID"
      }
    ]
  end
end

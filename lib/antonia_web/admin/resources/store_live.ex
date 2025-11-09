defmodule AntoniaWeb.Admin.Resources.StoreLive do
  @moduledoc """
  LiveResource for managing stores in the admin panel.
  """
  use Backpex.LiveResource,
    layout: {AntoniaWeb.Layouts, :admin},
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: Antonia.Revenue.Store,
      repo: Antonia.Repo,
      update_changeset: &Antonia.Revenue.Store.changeset/3,
      create_changeset: &Antonia.Revenue.Store.changeset/3
    ],
    pubsub: [server: Antonia.PubSub]

  @impl Backpex.LiveResource
  def singular_name, do: "Store"

  @impl Backpex.LiveResource
  def plural_name, do: "Stores"

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Name"
      },
      email: %{
        module: Backpex.Fields.Text,
        label: "Email"
      },
      area: %{
        module: Backpex.Fields.Number,
        label: "Area"
      },
      building_id: %{
        module: Backpex.Fields.Text,
        label: "Building ID"
      }
    ]
  end
end


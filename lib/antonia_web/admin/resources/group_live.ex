defmodule AntoniaWeb.Admin.Resources.GroupLive do
  @moduledoc """
  LiveResource for managing groups in the admin panel.
  """
  use Backpex.LiveResource,
    layout: {AntoniaWeb.Layouts, :admin},
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: Antonia.Revenue.Group,
      repo: Antonia.Repo,
      update_changeset: &Antonia.Revenue.Group.changeset/3,
      create_changeset: &Antonia.Revenue.Group.changeset/3
    ],
    pubsub: [server: Antonia.PubSub]

  @impl Backpex.LiveResource
  def singular_name, do: "Group"

  @impl Backpex.LiveResource
  def plural_name, do: "Groups"

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Name"
      },
      default_currency: %{
        module: Backpex.Fields.Text,
        label: "Default Currency"
      },
      created_by_user_id: %{
        module: Backpex.Fields.Text,
        label: "Created By User ID"
      }
    ]
  end
end

defmodule AntoniaWeb.Admin.Resources.UserLive do
  @moduledoc """
  LiveResource for managing users in the admin panel.
  """
  use Backpex.LiveResource,
    layout: {AntoniaWeb.Layouts, :admin},
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: Antonia.Accounts.User,
      repo: Antonia.Repo,
      update_changeset: &Antonia.Accounts.User.changeset/3,
      create_changeset: &Antonia.Accounts.User.changeset/3
    ],
    pubsub: [server: Antonia.PubSub]

  @impl Backpex.LiveResource
  def singular_name, do: "User"

  @impl Backpex.LiveResource
  def plural_name, do: "Users"

  @impl Backpex.LiveResource
  def fields do
    [
      email: %{
        module: Backpex.Fields.Text,
        label: "Email"
      },
      first_name: %{
        module: Backpex.Fields.Text,
        label: "First Name"
      },
      last_name: %{
        module: Backpex.Fields.Text,
        label: "Last Name"
      },
      provider: %{
        module: Backpex.Fields.Select,
        label: "Provider",
        options: [
          {"Google", :google},
          {"Kinde", :kinde}
        ]
      },
      location: %{
        module: Backpex.Fields.Text,
        label: "Location"
      },
      image: %{
        module: Backpex.Fields.Text,
        label: "Image URL"
      }
    ]
  end
end

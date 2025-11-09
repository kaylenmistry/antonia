defmodule AntoniaWeb.Admin.Resources.AttachmentLive do
  @moduledoc """
  LiveResource for managing attachments in the admin panel.
  """
  use Backpex.LiveResource,
    layout: {AntoniaWeb.Layouts, :admin},
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: Antonia.Revenue.Attachment,
      repo: Antonia.Repo,
      update_changeset: &Antonia.Revenue.Attachment.changeset/3,
      create_changeset: &Antonia.Revenue.Attachment.changeset/3
    ],
    pubsub: [server: Antonia.PubSub]

  @impl Backpex.LiveResource
  def singular_name, do: "Attachment"

  @impl Backpex.LiveResource
  def plural_name, do: "Attachments"

  @impl Backpex.LiveResource
  def fields do
    [
      s3_key: %{
        module: Backpex.Fields.Text,
        label: "S3 Key"
      },
      filename: %{
        module: Backpex.Fields.Text,
        label: "Filename"
      },
      file_type: %{
        module: Backpex.Fields.Text,
        label: "File Type"
      },
      file_size: %{
        module: Backpex.Fields.Number,
        label: "File Size"
      },
      report_id: %{
        module: Backpex.Fields.Text,
        label: "Report ID"
      }
    ]
  end
end


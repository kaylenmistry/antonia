defmodule AntoniaWeb.Admin.Resources.EmailLogLive do
  @moduledoc """
  LiveResource for managing email logs in the admin panel.
  """
  use Backpex.LiveResource,
    layout: {AntoniaWeb.Layouts, :admin},
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: Antonia.Revenue.EmailLog,
      repo: Antonia.Repo,
      update_changeset: &Antonia.Revenue.EmailLog.changeset/3,
      create_changeset: &Antonia.Revenue.EmailLog.changeset/3
    ],
    pubsub: [server: Antonia.PubSub]

  @impl Backpex.LiveResource
  def singular_name, do: "Email Log"

  @impl Backpex.LiveResource
  def plural_name, do: "Email Logs"

  @impl Backpex.LiveResource
  def fields do
    [
      report_id: %{
        module: Backpex.Fields.Text,
        label: "Report ID"
      },
      email_type: %{
        module: Backpex.Fields.Select,
        label: "Email Type",
        options: [
          {"Initial Request", :initial_request},
          {"Monthly Reminder", :monthly_reminder},
          {"Overdue Reminder", :overdue_reminder}
        ]
      },
      recipient_email: %{
        module: Backpex.Fields.Text,
        label: "Recipient Email"
      },
      subject: %{
        module: Backpex.Fields.Text,
        label: "Subject"
      },
      status: %{
        module: Backpex.Fields.Select,
        label: "Status",
        options: [
          {"Pending", :pending},
          {"Sent", :sent},
          {"Failed", :failed}
        ]
      },
      sent_at: %{
        module: Backpex.Fields.DateTime,
        label: "Sent At"
      },
      error_message: %{
        module: Backpex.Fields.Text,
        label: "Error Message"
      }
    ]
  end
end

defmodule AntoniaWeb.Admin.Resources.ReportLive do
  @moduledoc """
  LiveResource for managing reports in the admin panel.
  """
  use Backpex.LiveResource,
    layout: {AntoniaWeb.Layouts, :admin},
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: Antonia.Revenue.Report,
      repo: Antonia.Repo,
      update_changeset: &Antonia.Revenue.Report.changeset/3,
      create_changeset: &Antonia.Revenue.Report.changeset/3
    ],
    pubsub: [server: Antonia.PubSub]

  @impl Backpex.LiveResource
  def singular_name, do: "Report"

  @impl Backpex.LiveResource
  def plural_name, do: "Reports"

  @impl Backpex.LiveResource
  def fields do
    [
      status: %{
        module: Backpex.Fields.Select,
        label: "Status",
        options: [
          {"Pending", :pending},
          {"Submitted", :submitted},
          {"Approved", :approved}
        ]
      },
      currency: %{
        module: Backpex.Fields.Text,
        label: "Currency"
      },
      revenue: %{
        module: Backpex.Fields.Number,
        label: "Revenue"
      },
      period_start: %{
        module: Backpex.Fields.Date,
        label: "Period Start"
      },
      period_end: %{
        module: Backpex.Fields.Date,
        label: "Period End"
      },
      due_date: %{
        module: Backpex.Fields.Date,
        label: "Due Date"
      },
      note: %{
        module: Backpex.Fields.Text,
        label: "Note"
      },
      store_id: %{
        module: Backpex.Fields.Text,
        label: "Store ID"
      }
    ]
  end
end


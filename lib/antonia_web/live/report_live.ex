defmodule AntoniaWeb.ReportLive do
  use AntoniaWeb, :live_view

  alias Antonia.Repo
  alias Antonia.Revenue.Report

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    report = Repo.get(Report, id)

    if report do
      report = Repo.preload(report, [:store, store: :shopping_centre])

      {:ok, assign(socket, :report, report)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Report not found")
       |> push_navigate(to: ~p"/app")}
    end
  end
end

defmodule AntoniaWeb.ReportLive do
  @moduledoc """
  LiveView for report submission.
  """
  use AntoniaWeb, :live_view

  alias Antonia.Repo
  alias Antonia.Revenue.Report

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    report = Repo.get(Report, id)

    if report do
      report = Repo.preload(report, [:store, store: :building])

      {:ok, assign(socket, :report, report)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Report not found")
       |> push_navigate(to: ~p"/reporting")}
    end
  end
end

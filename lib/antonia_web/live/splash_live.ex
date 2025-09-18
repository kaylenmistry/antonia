defmodule AntoniaWeb.SplashLive do
  @moduledoc """
  LiveView for Splash page
  """
  use AntoniaWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("navigate-to-app", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/app")}
  end
end

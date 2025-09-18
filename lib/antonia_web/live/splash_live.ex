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

  @impl Phoenix.LiveView
  def handle_event("navigate-to-login", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/login")}
  end

  @impl Phoenix.LiveView
  def handle_event("navigate-to-signup", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/signup")}
  end

  @impl Phoenix.LiveView
  def handle_event("logout", _, socket) do
    # For now, just redirect to home - this will be implemented properly later
    {:noreply, push_navigate(socket, to: ~p"/")}
  end
end

defmodule AntoniaWeb.SplashLive do
  @moduledoc """
  LiveView for Splash page
  """
  use AntoniaWeb, :live_view

  alias Ueberauth.Auth

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    user =
      case session["auth"] do
        %Auth{info: %Auth.Info{} = user_info} -> user_info
        _ -> nil
      end

    {:ok, assign(socket, user: user)}
  end

  @impl Phoenix.LiveView
  def handle_event("navigate-to-app", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/auth")}
  end

  @impl Phoenix.LiveView
  def handle_event("navigate-to-login", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/auth")}
  end

  @impl Phoenix.LiveView
  def handle_event("navigate-to-signup", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/auth")}
  end

  @impl Phoenix.LiveView
  def handle_event("logout", _, socket) do
    # For now, just redirect to home - this will be implemented properly later
    {:noreply, push_navigate(socket, to: ~p"/")}
  end
end

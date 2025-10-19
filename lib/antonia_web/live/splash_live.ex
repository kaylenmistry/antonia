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
end

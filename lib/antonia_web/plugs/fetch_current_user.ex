defmodule AntoniaWeb.Plugs.FetchCurrentUser do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn
  alias Ueberauth.Auth

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _) do
    conn = fetch_cookies(conn)

    case get_session(conn, :auth) do
      %Auth{info: %Auth.Info{} = user} -> assign(conn, :current_user, user)
      _ -> assign(conn, :current_user, nil)
    end
  end
end

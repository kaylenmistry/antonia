defmodule AntoniaWeb.Plugs.ReferrerPolicy do
  @moduledoc """
  Sets the "Referrer-Policy" ("referer" header) to "strict-origin-when-cross-origin" on redirection, before sending the response. Else returns the connection, unmodified.

  See the following for more information:
    - https://owasp.org/www-project-secure-headers/#referrer-policy
    - https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Referrer-Policy
    - https://web.dev/referrer-best-practices/
  """

  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(_) do
    []
  end

  @impl Plug
  def call(conn, _opts) do
    register_before_send(conn, fn conn ->
      # Set "strict-origin-when-cross-origin" referrer policy on 3XX statuses
      if conn.status in 300..399 do
        put_resp_header(conn, "referrer-policy", "strict-origin-when-cross-origin")
      else
        conn
      end
    end)
  end
end

defmodule AntoniaWeb.Plugs.VerifyHostTest do
  use AntoniaWeb.ConnCase

  alias AntoniaWeb.Plugs.VerifyHost

  describe "call/2" do
    test "should return conn unchanged if valid host", %{conn: conn} do
      conn = VerifyHost.call(conn, [])

      refute conn.status == 301
    end

    test "should redirect if host is not valid", %{conn: conn} do
      conn =
        conn
        |> Map.put(:host, "some-other-domain.com")
        |> VerifyHost.call([])

      # Assert redirected to base_url with request path
      assert redirected_to(conn, 301) == "http://localhost:4100/"
    end
  end
end

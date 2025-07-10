defmodule AntoniaWeb.Plugs.ReferrerPolicyTest do
  use AntoniaWeb.ConnCase

  import Plug.Conn

  alias AntoniaWeb.Plugs.ReferrerPolicy

  setup %{conn: conn} do
    %{conn: init_test_session(conn, %{})}
  end

  describe "call/2" do
    test "should set the referrer policy to strict-origin-when-cross-origin on 3XX (redirection) status",
         %{
           conn: conn
         } do
      for status <- 300..308 do
        conn =
          conn
          |> ReferrerPolicy.call([])
          |> send_resp(status, "")

        assert get_resp_header(conn, "referrer-policy") == ["strict-origin-when-cross-origin"]
      end
    end

    test "should not set the referrer policy otherwise", %{conn: conn} do
      for status <- [100, 200, 400, 500, 999] do
        conn =
          conn
          |> ReferrerPolicy.call([])
          |> send_resp(status, "")

        assert get_resp_header(conn, "referrer-policy") == []
      end
    end
  end
end

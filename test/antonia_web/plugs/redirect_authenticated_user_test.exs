defmodule AntoniaWeb.Plugs.RedirectAuthenticatedUserTest do
  use AntoniaWeb.ConnCase, async: true

  alias AntoniaWeb.Plugs.RedirectAuthenticatedUser
  alias Ueberauth.Auth

  describe "call/2" do
    test "redirects to /app when user is authenticated" do
      auth = %Auth{
        uid: "user_123",
        info: %Auth.Info{
          email: "test@example.com",
          first_name: "Test",
          last_name: "User"
        },
        credentials: %Auth.Credentials{
          token: "access_token_123",
          expires_at: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()
        }
      }

      conn =
        build_conn()
        |> init_test_session(%{})
        |> put_session(:auth, auth)
        |> RedirectAuthenticatedUser.call([])

      assert conn.halted
      assert redirected_to(conn) == "/app"
    end

    test "allows request when user is not authenticated" do
      conn =
        build_conn()
        |> init_test_session(%{})
        |> RedirectAuthenticatedUser.call([])

      refute conn.halted
    end

    test "allows request when auth session is nil" do
      conn =
        build_conn()
        |> init_test_session(%{})
        |> put_session(:auth, nil)
        |> RedirectAuthenticatedUser.call([])

      refute conn.halted
    end
  end
end

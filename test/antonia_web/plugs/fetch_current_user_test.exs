defmodule AntoniaWeb.Plugs.FetchCurrentUserTest do
  use AntoniaWeb.ConnCase, async: true

  alias AntoniaWeb.Plugs.FetchCurrentUser
  alias Ueberauth.Auth

  describe "call/2" do
    test "assigns user when auth session exists" do
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
        |> FetchCurrentUser.call([])

      assert conn.assigns[:user] == auth.info
      refute conn.halted
    end

    test "assigns nil when no auth session exists" do
      conn =
        build_conn()
        |> init_test_session(%{})
        |> FetchCurrentUser.call([])

      assert conn.assigns[:user] == nil
      refute conn.halted
    end

    test "assigns nil when auth session exists but info is not Auth.Info struct" do
      invalid_auth = %Auth{
        uid: "user_456",
        info: nil,
        credentials: %Auth.Credentials{
          token: "access_token_456",
          expires_at: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()
        }
      }

      conn =
        build_conn()
        |> init_test_session(%{})
        |> put_session(:auth, invalid_auth)
        |> FetchCurrentUser.call([])

      assert conn.assigns[:user] == nil
      refute conn.halted
    end
  end
end

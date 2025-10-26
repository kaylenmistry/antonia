defmodule AntoniaWeb.Plugs.RequireAuthenticatedUserTest do
  use AntoniaWeb.ConnCase, async: true

  import Mock

  alias Antonia.Services.Kinde
  alias AntoniaWeb.Plugs.RequireAuthenticatedUser
  alias Ueberauth.Auth

  describe "call/2" do
    test "allows request when token is valid and not expired" do
      auth = %Auth{
        uid: "user_123",
        info: %Auth.Info{
          email: "test@example.com",
          first_name: "Test",
          last_name: "User"
        },
        credentials: %Auth.Credentials{
          expires_at: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix(),
          refresh_token: "refresh_token_123",
          token: "access_token_123"
        }
      }

      with_mock Kinde, [:passthrough], maybe_refresh_token: fn _auth -> {:ok, auth} end do
        conn =
          build_conn()
          |> init_test_session(%{})
          |> put_session(:auth, auth)
          |> RequireAuthenticatedUser.call([])

        refute conn.halted
        assert get_session(conn, :auth) == auth
      end
    end

    test "refreshes expired token and allows request" do
      expired_auth = %Auth{
        uid: "user_456",
        info: %Auth.Info{
          email: "expired@example.com",
          first_name: "Expired",
          last_name: "User"
        },
        credentials: %Auth.Credentials{
          expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.to_unix(),
          refresh_token: "refresh_token_456",
          token: "access_token_456"
        }
      }

      refreshed_auth = %{
        expired_auth
        | credentials: %{
            expired_auth.credentials
            | expires_at: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()
          }
      }

      with_mock Kinde, [:passthrough],
        maybe_refresh_token: fn _auth -> {:ok, refreshed_auth} end do
        conn =
          build_conn()
          |> init_test_session(%{})
          |> put_session(:auth, expired_auth)
          |> RequireAuthenticatedUser.call([])

        refute conn.halted
        assert get_session(conn, :auth) == refreshed_auth
      end
    end

    test "redirects to login when refresh fails" do
      expired_auth = %Auth{
        uid: "user_789",
        info: %Auth.Info{
          email: "failed@example.com",
          first_name: "Failed",
          last_name: "User"
        },
        credentials: %Auth.Credentials{
          expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.to_unix(),
          refresh_token: "refresh_token_789",
          token: "access_token_789"
        }
      }

      with_mock Kinde, [:passthrough],
        maybe_refresh_token: fn _auth -> {:error, :refresh_failed} end do
        conn =
          build_conn()
          |> init_test_session(%{})
          |> put_session(:auth, expired_auth)
          |> RequireAuthenticatedUser.call([])

        assert conn.halted
        assert redirected_to(conn) == "/auth/login"
        assert get_session(conn, :auth) == nil
      end
    end

    test "redirects to login when no auth session exists" do
      with_mock Kinde, [:passthrough],
        maybe_refresh_token: fn _auth -> {:error, :invalid_auth} end do
        conn =
          build_conn()
          |> init_test_session(%{})
          |> RequireAuthenticatedUser.call([])

        assert conn.halted
        assert redirected_to(conn) == "/auth/login"
        assert get_session(conn, :auth) == nil
      end
    end

    test "stores return_to path for GET requests" do
      with_mock Kinde, [:passthrough],
        maybe_refresh_token: fn _auth -> {:error, :invalid_auth} end do
        conn =
          :get
          |> build_conn("/app/some-page")
          |> init_test_session(%{})
          |> RequireAuthenticatedUser.call([])

        assert conn.halted
        assert redirected_to(conn) == "/auth/login"
        assert get_session(conn, :user_return_to) == "/app/some-page"
      end
    end

    test "does not store return_to path for non-GET requests" do
      with_mock Kinde, [:passthrough],
        maybe_refresh_token: fn _auth -> {:error, :invalid_auth} end do
        conn =
          :post
          |> build_conn("/app/some-action")
          |> init_test_session(%{})
          |> RequireAuthenticatedUser.call([])

        assert conn.halted
        assert redirected_to(conn) == "/auth/login"
        assert get_session(conn, :user_return_to) == nil
      end
    end

    test "clears session on authentication failure" do
      with_mock Kinde, [:passthrough],
        maybe_refresh_token: fn _auth -> {:error, :invalid_auth} end do
        conn =
          build_conn()
          |> init_test_session(%{some_other_session: "value"})
          |> RequireAuthenticatedUser.call([])

        assert conn.halted
        assert redirected_to(conn) == "/auth/login"
        # Session should be cleared except for user_return_to
        assert get_session(conn, :some_other_session) == nil
      end
    end
  end
end

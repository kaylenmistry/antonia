defmodule AntoniaWeb.AuthControllerTest do
  use AntoniaWeb.ConnCase

  import Mock

  alias Antonia.Accounts
  alias Antonia.Accounts.User
  alias AntoniaWeb.AuthController
  alias Phoenix.Flash
  alias Ueberauth.Auth

  @auth %Auth{
    uid: "kinde_user_123",
    provider: :kinde,
    info: %Auth.Info{
      first_name: "Test",
      last_name: "User",
      email: "test@example.com",
      image: nil
    },
    credentials: %Auth.Credentials{
      token: "access_token_123",
      expires_at: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()
    }
  }

  describe "GET /auth/login" do
    test "redirects to Kinde login page with nonce", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get(~p"/auth/login")

      assert redirected_to(conn) =~ "/auth/kinde?prompt=login&nonce="

      # Check that nonce is stored in session
      assert get_session(conn, :oauth_nonce) != nil
    end
  end

  describe "GET /auth/register" do
    test "redirects to Kinde registration page with nonce", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get(~p"/auth/register")

      assert redirected_to(conn) =~ "/auth/kinde?prompt=create&nonce="

      # Check that nonce is stored in session
      assert get_session(conn, :oauth_nonce) != nil
    end
  end

  describe "GET /auth/logout" do
    test "redirects to Kinde logout URL and broadcasts disconnect", %{conn: conn} do
      live_socket_id = "users_sessions:test_user"

      conn =
        conn
        |> init_test_session(%{})
        |> put_session(:auth, @auth)
        |> put_session(:live_socket_id, live_socket_id)

      # Mock the broadcast call
      with_mock AntoniaWeb.Endpoint, [:passthrough],
        broadcast: fn _topic, _event, _payload -> :ok end do
        conn = get(conn, ~p"/auth/logout")

        # Should redirect to Kinde logout URL
        assert redirected_to(conn) =~ "/logout"
        assert redirected_to(conn) =~ "redirect="

        # Session should be cleared
        assert get_session(conn, :auth) == nil
        assert get_session(conn, :live_socket_id) == nil
      end
    end

    test "redirects even when no live_socket_id is present", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> put_session(:auth, @auth)
        |> get(~p"/auth/logout")

      # Should redirect to Kinde logout URL
      assert redirected_to(conn) =~ "/logout"
      assert redirected_to(conn) =~ "redirect="
    end
  end

  describe "GET /auth/:provider/callback" do
    test "redirects to home with error flash when authentication fails", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> assign(:ueberauth_failure, %Ueberauth.Failure{})
        |> get(~p"/auth/kinde/callback")

      assert redirected_to(conn) == ~p"/"
      assert Flash.get(conn.assigns.flash, :error) == "Failed to authenticate."
    end

    test "creates user and redirects to /app when authentication is successful", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> assign(:ueberauth_auth, @auth)
        |> fetch_session()
        # bypass CSRF verification
        |> AuthController.callback(%{})

      # User is persisted in the database
      assert %User{
               email: "test@example.com",
               first_name: "Test",
               last_name: "User"
             } = Accounts.get_user_by_email("test@example.com")

      # User is redirected to app page
      assert redirected_to(conn) == ~p"/app"

      # Session should have auth and live_socket_id
      assert get_session(conn, :auth) != nil
      assert get_session(conn, :live_socket_id) != nil
    end

    test "updates existing user when user with same email already exists", %{conn: conn} do
      # Create an existing user
      {:ok, existing_user} =
        Accounts.create_or_update_user(%{
          uid: "old_uid",
          provider: :kinde,
          email: "test@example.com",
          first_name: "Old",
          last_name: "Name"
        })

      # Now authenticate with new data
      conn =
        conn
        |> init_test_session(%{})
        |> assign(:ueberauth_auth, @auth)
        |> fetch_session()
        |> AuthController.callback(%{})

      # User should be updated with new information
      updated_user = Accounts.get_user_by_email("test@example.com")
      assert updated_user.id == existing_user.id
      assert updated_user.first_name == "Test"
      assert updated_user.last_name == "User"

      # User is redirected to app page
      assert redirected_to(conn) == ~p"/app"
    end

    test "redirects to :user_return_to url if present", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> assign(:ueberauth_auth, @auth)
        |> put_session(:user_return_to, "/app/some-page")
        |> fetch_session()
        |> AuthController.callback(%{})

      # User is redirected to previous page
      assert redirected_to(conn) == "/app/some-page"
    end

    test "creates user with uid set to database user id, not auth uid", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> assign(:ueberauth_auth, @auth)
        |> fetch_session()
        |> AuthController.callback(%{})

      # The auth session should have the local user id as uid, not the Kinde uid
      session_auth = get_session(conn, :auth)
      assert session_auth.uid != "kinde_user_123"
      assert session_auth.uid != nil

      # The extra field should be nil
      assert session_auth.extra == nil
    end
  end
end

defmodule Ueberauth.Strategy.KindeTest do
  use ExUnit.Case, async: false

  import Mock
  import Plug.Test
  import Plug.Conn
  import Ueberauth.Strategy.Helpers

  alias Plug.Conn.Query
  alias Ueberauth.Strategy.Kinde.OAuth

  setup_with_mocks([
    {OAuth2.Client, [:passthrough],
     [
       get_token: &oauth2_get_token/2,
       get: &oauth2_get/4
     ]}
  ]) do
    # Configure OAuth client with default values
    Application.put_env(:ueberauth, OAuth,
      client_id: "client_id",
      client_secret: "client_secret",
      domain: "https://test.kinde.com"
    )

    # Create a connection with Ueberauth's CSRF cookies so they can be recycled during tests
    routes = Ueberauth.init([])
    csrf_conn = Ueberauth.call(conn(:get, "/auth/kinde", %{}), routes)
    csrf_state = Keyword.get(with_state_param([], csrf_conn), :state)

    {:ok, csrf_conn: csrf_conn, csrf_state: csrf_state}
  end

  def set_options(routes, conn, opt) do
    case Enum.find_index(routes, &(elem(&1, 0) == {conn.request_path, conn.method})) do
      nil ->
        routes

      idx ->
        update_in(routes, [Access.at(idx), Access.elem(1), Access.elem(2)], &%{&1 | options: opt})
    end
  end

  defp token(client, opts), do: {:ok, %{client | token: OAuth2.AccessToken.new(opts)}}
  defp response(body, code \\ 200), do: {:ok, %OAuth2.Response{status_code: code, body: body}}

  def oauth2_get_token(client, code: "success_code"), do: token(client, "success_token")
  def oauth2_get_token(client, code: "uid_code"), do: token(client, "uid_token")
  def oauth2_get_token(client, code: "userinfo_code"), do: token(client, "userinfo_token")

  def oauth2_get_token(_client, code: "oauth2_error"),
    do: {:error, %OAuth2.Error{reason: :timeout}}

  def oauth2_get_token(_client, code: "error_response"),
    do:
      {:error,
       %OAuth2.Response{
         body: %{"error" => "some error", "error_description" => "something went wrong"}
       }}

  def oauth2_get_token(_client, code: "error_response_no_description"),
    do: {:error, %OAuth2.Response{body: %{"error" => "internal_failure"}}}

  def oauth2_get(%{token: %{access_token: "success_token"}}, _url, _, _),
    do:
      response(%{
        "id" => "1234_fred",
        "sub" => "1234_fred",
        "name" => "Fred Jones",
        "preferred_email" => "fred_jones@example.com",
        "first_name" => "Fred",
        "last_name" => "Jones"
      })

  def oauth2_get(%{token: %{access_token: "uid_token"}}, _url, _, _),
    do: response(%{"id" => "1234_daphne", "name" => "Daphne Blake"})

  def oauth2_get(%{token: %{access_token: "userinfo_token"}}, "/oauth2/user_profile", _, _),
    do: response(%{"sub" => "1234_velma", "name" => "Velma Dinkley"})

  def oauth2_get(
        %{token: %{access_token: "userinfo_token"}},
        "https://test.kinde.com/oauth2/user_profile",
        _,
        _
      ),
      do: response(%{"sub" => "1234_velma", "name" => "Velma Dinkley"})

  def oauth2_get(%{token: %{access_token: "userinfo_token"}}, "example.com/shaggy", _, _),
    do: response(%{"sub" => "1234_shaggy", "name" => "Norville Rogers"})

  def oauth2_get(%{token: %{access_token: "userinfo_token"}}, "/api/v1/organization", _, _),
    do: response(%{"code" => "org_123", "name" => "Test Organization"})

  def oauth2_get(%{token: %{access_token: "userinfo_token"}}, "example.com/scooby", _, _),
    do: response(%{"sub" => "1234_scooby", "name" => "Scooby Doo"})

  defp set_csrf_cookies(conn, csrf_conn) do
    conn
    |> init_test_session(%{})
    |> recycle_cookies(csrf_conn)
    |> fetch_cookies()
  end

  test "handle_request! redirects to appropriate auth uri" do
    conn = conn(:get, "/auth/kinde", %{prompt: "login"})

    routes = set_options(Ueberauth.init(), conn, domain: "https://test.kinde.com")
    resp = Ueberauth.call(conn, routes)

    assert resp.status == 302
    assert [location] = get_resp_header(resp, "location")

    redirect_uri = URI.parse(location)
    assert redirect_uri.host == "test.kinde.com"
    assert redirect_uri.path == "/oauth2/auth"

    assert %{
             "client_id" => "client_id",
             "redirect_uri" => "http://www.example.com/auth/kinde/callback",
             "response_type" => "code",
             "scope" => scope,
             "prompt" => "login"
           } = Query.decode(redirect_uri.query)

    # Check that the scope contains the expected values
    assert "openid" in String.split(scope, " ")
    assert "profile" in String.split(scope, " ")
    assert "email" in String.split(scope, " ")
  end

  test "handle_callback! assigns required fields on successful auth", %{
    csrf_state: csrf_state,
    csrf_conn: csrf_conn
  } do
    conn =
      set_csrf_cookies(
        conn(:get, "/auth/kinde/callback", %{code: "success_code", state: csrf_state}),
        csrf_conn
      )

    routes = Ueberauth.init([])
    assert %Plug.Conn{assigns: %{ueberauth_auth: auth}} = Ueberauth.call(conn, routes)
    assert auth.credentials.token == "success_token"
    assert auth.info.name == "Fred Jones"
    assert auth.info.email == "fred_jones@example.com"
    assert auth.info.first_name == "Fred"
    assert auth.info.last_name == "Jones"
    assert auth.uid == "1234_fred"
  end

  test "uid_field is picked according to the specified option", %{
    csrf_state: csrf_state,
    csrf_conn: csrf_conn
  } do
    conn =
      set_csrf_cookies(
        conn(:get, "/auth/kinde/callback", %{code: "uid_code", state: csrf_state}),
        csrf_conn
      )

    routes = set_options(Ueberauth.init(), conn, uid_field: "id")
    assert %Plug.Conn{assigns: %{ueberauth_auth: auth}} = Ueberauth.call(conn, routes)
    assert auth.info.name == "Daphne Blake"
    assert auth.uid == "1234_daphne"
  end

  test "userinfo is fetched according to userinfo_endpoint", %{
    csrf_state: csrf_state,
    csrf_conn: csrf_conn
  } do
    conn =
      set_csrf_cookies(
        conn(:get, "/auth/kinde/callback", %{code: "userinfo_code", state: csrf_state}),
        csrf_conn
      )

    routes = set_options(Ueberauth.init(), conn, userinfo_endpoint: "example.com/shaggy")
    assert %Plug.Conn{assigns: %{ueberauth_auth: auth}} = Ueberauth.call(conn, routes)
    assert auth.info.name == "Norville Rogers"
  end

  test "userinfo can be set via runtime config with default", %{
    csrf_state: csrf_state,
    csrf_conn: csrf_conn
  } do
    conn =
      set_csrf_cookies(
        conn(:get, "/auth/kinde/callback", %{code: "userinfo_code", state: csrf_state}),
        csrf_conn
      )

    routes =
      set_options(Ueberauth.init(), conn,
        userinfo_endpoint: {:system, "NOT_SET", "example.com/shaggy"}
      )

    assert %Plug.Conn{assigns: %{ueberauth_auth: auth}} = Ueberauth.call(conn, routes)
    assert auth.info.name == "Norville Rogers"
  end

  test "userinfo uses default library value if runtime env not found", %{
    csrf_state: csrf_state,
    csrf_conn: csrf_conn
  } do
    conn =
      set_csrf_cookies(
        conn(:get, "/auth/kinde/callback", %{code: "userinfo_code", state: csrf_state}),
        csrf_conn
      )

    routes = set_options(Ueberauth.init(), conn, userinfo_endpoint: {:system, "NOT_SET"})
    assert %Plug.Conn{assigns: %{ueberauth_auth: auth}} = Ueberauth.call(conn, routes)
    assert auth.info.name == "Velma Dinkley"
  end

  test "userinfo can be set via runtime config", %{csrf_state: csrf_state, csrf_conn: csrf_conn} do
    conn =
      set_csrf_cookies(
        conn(:get, "/auth/kinde/callback", %{code: "userinfo_code", state: csrf_state}),
        csrf_conn
      )

    routes =
      set_options(Ueberauth.init(), conn, userinfo_endpoint: {:system, "UEBERAUTH_SCOOBY_DOO"})

    System.put_env("UEBERAUTH_SCOOBY_DOO", "example.com/scooby")
    assert %Plug.Conn{assigns: %{ueberauth_auth: auth}} = Ueberauth.call(conn, routes)
    assert auth.info.name == "Scooby Doo"
    System.delete_env("UEBERAUTH_SCOOBY_DOO")
  end

  test "state param is present in the redirect uri" do
    conn = conn(:get, "/auth/kinde", %{})

    routes = Ueberauth.init()
    resp = Ueberauth.call(conn, routes)

    assert [location] = get_resp_header(resp, "location")

    redirect_uri = URI.parse(location)

    assert redirect_uri.query =~ "state="
  end

  describe "error handling" do
    test "handle_callback! handles Oauth2.Error", %{csrf_state: csrf_state, csrf_conn: csrf_conn} do
      conn =
        set_csrf_cookies(
          conn(:get, "/auth/kinde/callback", %{code: "oauth2_error", state: csrf_state}),
          csrf_conn
        )

      routes = Ueberauth.init([])
      assert %Plug.Conn{assigns: %{ueberauth_failure: failure}} = Ueberauth.call(conn, routes)

      assert %Ueberauth.Failure{
               errors: [%Ueberauth.Failure.Error{message: "timeout", message_key: "error"}]
             } = failure
    end

    test "handle_callback! handles error response", %{
      csrf_state: csrf_state,
      csrf_conn: csrf_conn
    } do
      conn =
        set_csrf_cookies(
          conn(:get, "/auth/kinde/callback", %{code: "error_response", state: csrf_state}),
          csrf_conn
        )

      routes = Ueberauth.init([])
      assert %Plug.Conn{assigns: %{ueberauth_failure: failure}} = Ueberauth.call(conn, routes)

      assert %Ueberauth.Failure{
               errors: [
                 %Ueberauth.Failure.Error{
                   message: "something went wrong",
                   message_key: "some error"
                 }
               ]
             } = failure
    end

    test "handle_callback! handles error response without error_description", %{
      csrf_state: csrf_state,
      csrf_conn: csrf_conn
    } do
      conn =
        set_csrf_cookies(
          conn(:get, "/auth/kinde/callback", %{
            code: "error_response_no_description",
            state: csrf_state
          }),
          csrf_conn
        )

      routes = Ueberauth.init([])
      assert %Plug.Conn{assigns: %{ueberauth_failure: failure}} = Ueberauth.call(conn, routes)

      assert %Ueberauth.Failure{
               errors: [%Ueberauth.Failure.Error{message: "", message_key: "internal_failure"}]
             } = failure
    end
  end
end

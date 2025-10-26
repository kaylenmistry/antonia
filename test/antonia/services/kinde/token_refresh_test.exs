defmodule Antonia.Services.Kinde.TokenRefreshTest do
  use ExUnit.Case, async: false

  import Mock

  alias Antonia.Services.Kinde.TokenRefresh
  alias Ueberauth.Auth
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Info

  describe "maybe_refresh_token/1" do
    setup do
      # Create a valid auth struct
      valid_auth = %Auth{
        uid: "user_123",
        info: %Info{email: "test@example.com", name: "Test User"},
        credentials: %Credentials{
          expires_at: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix(),
          refresh_token: "refresh_token_123",
          token: "access_token_123"
        }
      }

      # Create an expired auth struct
      expired_auth = %Auth{
        uid: "user_456",
        info: %Info{email: "expired@example.com", name: "Expired User"},
        credentials: %Credentials{
          expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.to_unix(),
          refresh_token: "refresh_token_456",
          token: "access_token_456"
        }
      }

      %{valid_auth: valid_auth, expired_auth: expired_auth}
    end

    test "returns original auth when token is still valid", %{valid_auth: auth} do
      assert {:ok, ^auth} = TokenRefresh.maybe_refresh_token(auth)
    end

    @tag :capture_log
    test "returns error when refresh token is nil" do
      auth_without_refresh = %Auth{
        uid: "user_789",
        info: %Info{email: "norefresh@example.com", name: "No Refresh User"},
        credentials: %Credentials{
          expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.to_unix(),
          refresh_token: nil,
          token: "access_token_789"
        }
      }

      assert {:error, :no_refresh_token} = TokenRefresh.maybe_refresh_token(auth_without_refresh)
    end

    @tag :capture_log
    test "returns error for invalid auth struct" do
      assert {:error, :invalid_auth} = TokenRefresh.maybe_refresh_token(%{})
    end
  end

  describe "token refresh functionality" do
    setup do
      # Create an expired auth struct for refresh tests
      expired_auth = %Auth{
        uid: "user_456",
        info: %Info{email: "expired@example.com", name: "Expired User"},
        credentials: %Credentials{
          expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.to_unix(),
          refresh_token: "refresh_token_456",
          token: "access_token_456"
        }
      }

      %{expired_auth: expired_auth}
    end

    test "successfully refreshes expired token and preserves original auth data", %{
      expired_auth: auth
    } do
      # Mock JSON response from Kinde
      json_token_response = %{
        "access_token" => "new_access_token_123",
        "expires_in" => 3600,
        "id_token" => "new_id_token_123",
        "refresh_token" => "new_refresh_token_123",
        "scope" => "openid profile email offline",
        "token_type" => "Bearer"
      }

      # Create mock OAuth2.AccessToken with JSON access_token
      mock_token = %OAuth2.AccessToken{
        access_token: Jason.encode!(json_token_response),
        refresh_token: "new_refresh_token_123",
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix(),
        token_type: "Bearer",
        other_params: %{"scope" => "openid profile email offline"}
      }

      with_mocks([
        {OAuth2.Client, [],
         [
           get_token: fn _client -> {:ok, %OAuth2.Client{token: mock_token}} end,
           new: fn _client, opts ->
             %OAuth2.Client{
               strategy: Keyword.get(opts, :strategy),
               client_id: Keyword.get(opts, :client_id),
               client_secret: Keyword.get(opts, :client_secret),
               site: Keyword.get(opts, :site),
               params: Keyword.get(opts, :params)
             }
           end
         ]},
        {Ueberauth.Strategy.Kinde.OAuth, [],
         [
           client: fn ->
             %OAuth2.Client{
               client_id: "test_client",
               client_secret: "test_secret",
               site: "https://test.kinde.com"
             }
           end
         ]}
      ]) do
        assert {:ok, refreshed_auth} = TokenRefresh.maybe_refresh_token(auth)

        # Verify original auth data is preserved
        assert refreshed_auth.uid == auth.uid
        assert refreshed_auth.info == auth.info
        assert refreshed_auth.extra == auth.extra

        # Verify credentials are updated with new token data
        # The token is preserved as JSON string
        expected_json = Jason.encode!(json_token_response)
        assert refreshed_auth.credentials.token == expected_json
        assert refreshed_auth.credentials.refresh_token == "new_refresh_token_123"
        assert refreshed_auth.credentials.token_type == "Bearer"
        assert refreshed_auth.credentials.scopes == ["openid", "profile", "email", "offline"]
        assert refreshed_auth.credentials.expires == true
        assert refreshed_auth.credentials.expires_at > DateTime.to_unix(DateTime.utc_now())
      end
    end

    @tag :capture_log
    test "handles refresh token expiration error", %{expired_auth: auth} do
      with_mocks([
        {OAuth2.Client, [],
         [
           get_token: fn _client ->
             {:error, %OAuth2.Response{status_code: 401, body: "Unauthorized"}}
           end,
           new: fn _client, opts ->
             %OAuth2.Client{
               strategy: Keyword.get(opts, :strategy),
               client_id: Keyword.get(opts, :client_id),
               client_secret: Keyword.get(opts, :client_secret),
               site: Keyword.get(opts, :site),
               params: Keyword.get(opts, :params)
             }
           end
         ]},
        {Ueberauth.Strategy.Kinde.OAuth, [],
         [
           client: fn ->
             %OAuth2.Client{
               client_id: "test_client",
               client_secret: "test_secret",
               site: "https://test.kinde.com"
             }
           end
         ]}
      ]) do
        assert {:error, :refresh_token_expired} = TokenRefresh.maybe_refresh_token(auth)
      end
    end

    @tag :capture_log
    test "handles general refresh failure", %{expired_auth: auth} do
      with_mocks([
        {OAuth2.Client, [],
         [
           get_token: fn _client ->
             {:error, %OAuth2.Response{status_code: 500, body: "Internal Server Error"}}
           end,
           new: fn _client, opts ->
             %OAuth2.Client{
               strategy: Keyword.get(opts, :strategy),
               client_id: Keyword.get(opts, :client_id),
               client_secret: Keyword.get(opts, :client_secret),
               site: Keyword.get(opts, :site),
               params: Keyword.get(opts, :params)
             }
           end
         ]},
        {Ueberauth.Strategy.Kinde.OAuth, [],
         [
           client: fn ->
             %OAuth2.Client{
               client_id: "test_client",
               client_secret: "test_secret",
               site: "https://test.kinde.com"
             }
           end
         ]}
      ]) do
        assert {:error, :refresh_failed} = TokenRefresh.maybe_refresh_token(auth)
      end
    end

    @tag :capture_log
    test "handles malformed refresh token error", %{expired_auth: auth} do
      with_mocks([
        {OAuth2.Client, [],
         [
           get_token: fn _client ->
             {:error,
              %OAuth2.Response{
                status_code: 400,
                body: %{
                  "error" => "invalid_request",
                  "error_description" => "Refresh token provided is malformed."
                }
              }}
           end,
           new: fn _client, opts ->
             %OAuth2.Client{
               strategy: Keyword.get(opts, :strategy),
               client_id: Keyword.get(opts, :client_id),
               client_secret: Keyword.get(opts, :client_secret),
               site: Keyword.get(opts, :site),
               params: Keyword.get(opts, :params)
             }
           end
         ]},
        {Ueberauth.Strategy.Kinde.OAuth, [],
         [
           client: fn ->
             %OAuth2.Client{
               client_id: "test_client",
               client_secret: "test_secret",
               site: "https://test.kinde.com"
             }
           end
         ]}
      ]) do
        assert {:error, :refresh_failed} = TokenRefresh.maybe_refresh_token(auth)
      end
    end

    @tag :capture_log
    test "handles empty refresh token", %{expired_auth: auth} do
      auth_with_empty_refresh = %{auth | credentials: %{auth.credentials | refresh_token: ""}}

      assert {:error, :no_refresh_token} =
               TokenRefresh.maybe_refresh_token(auth_with_empty_refresh)
    end

    @tag :capture_log
    test "handles nil refresh token", %{expired_auth: auth} do
      auth_with_nil_refresh = %{auth | credentials: %{auth.credentials | refresh_token: nil}}
      assert {:error, :no_refresh_token} = TokenRefresh.maybe_refresh_token(auth_with_nil_refresh)
    end
  end

  describe "JSON token preservation behavior" do
    test "preserves JSON-encoded access_token and preserves original auth data" do
      original_auth = %Auth{
        uid: "user_123",
        info: %Info{email: "test@example.com", name: "Test User"},
        credentials: %Credentials{
          token: "old_token",
          expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.to_unix(),
          refresh_token: "refresh_token_123"
        },
        extra: %{raw_info: %{"sub" => "user_123"}}
      }

      # JSON response from Kinde
      json_token_response = %{
        "access_token" => "new_access_token_456",
        "expires_in" => 7200,
        "id_token" => "new_id_token_456",
        "refresh_token" => "new_refresh_token_456",
        "scope" => "openid profile email",
        "token_type" => "Bearer"
      }

      mock_token = %OAuth2.AccessToken{
        access_token: Jason.encode!(json_token_response),
        refresh_token: "new_refresh_token_456",
        expires_at: DateTime.utc_now() |> DateTime.add(7200, :second) |> DateTime.to_unix(),
        token_type: "Bearer",
        other_params: %{"scope" => "openid profile email"}
      }

      # Test the build_auth_from_token function directly using reflection
      result = :erlang.apply(TokenRefresh, :build_auth_from_token, [mock_token, original_auth])

      # Verify original auth data is preserved
      assert result.uid == original_auth.uid
      assert result.info == original_auth.info
      assert result.extra == original_auth.extra

      # Verify credentials are updated - token is preserved as JSON string
      expected_json = Jason.encode!(json_token_response)
      assert result.credentials.token == expected_json
      assert result.credentials.refresh_token == "new_refresh_token_456"
      assert result.credentials.token_type == "Bearer"
      assert result.credentials.scopes == ["openid", "profile", "email"]
      assert result.credentials.expires == true
      assert result.credentials.expires_at > DateTime.to_unix(DateTime.utc_now())
    end
  end
end

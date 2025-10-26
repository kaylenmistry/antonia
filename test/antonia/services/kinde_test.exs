defmodule Antonia.Services.KindeTest do
  use Antonia.DataCase, async: true

  alias Antonia.Services.Kinde
  alias Ueberauth.Auth

  describe "generate_portal_link/2" do
    @tag :capture_log
    test "delegates to Portal.generate_link/2" do
      access_token = "test-token"
      opts = [sub_nav: :profile]

      assert Kinde.generate_portal_link(access_token, opts) ==
               Kinde.Portal.generate_link(access_token, opts)
    end

    @tag :capture_log
    test "delegates to Portal.generate_link/2 with return_url" do
      access_token = "test-token"
      opts = [sub_nav: :profile, return_url: "https://example.com/app"]

      assert Kinde.generate_portal_link(access_token, opts) ==
               Kinde.Portal.generate_link(access_token, opts)
    end
  end

  describe "create_organisation/2" do
    @tag :capture_log
    test "delegates to CreateOrganisation.create_organisation/2" do
      access_token = "test-token"
      organisation_params = %{name: "Test Org"}

      assert Kinde.create_organisation(access_token, organisation_params) ==
               Kinde.CreateOrganisation.create_organisation(access_token, organisation_params)
    end
  end

  describe "config/0" do
    test "returns application configuration" do
      config = Kinde.config()
      assert is_list(config) or is_map(config)
      assert Keyword.has_key?(config, :domain) or Map.has_key?(config, :domain)
    end
  end

  describe "maybe_refresh_token/1" do
    @tag :capture_log
    test "delegates to TokenRefresh.maybe_refresh_token/1" do
      auth = %Auth{
        uid: "user_123",
        provider: :kinde,
        info: %Ueberauth.Auth.Info{
          email: "test@example.com",
          first_name: "Test",
          last_name: "User"
        },
        credentials: %Ueberauth.Auth.Credentials{
          token: "access_token",
          refresh_token: "refresh_token",
          expires_at: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()
        }
      }

      assert Kinde.maybe_refresh_token(auth) ==
               Kinde.TokenRefresh.maybe_refresh_token(auth)
    end
  end
end

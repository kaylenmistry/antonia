defmodule Ueberauth.Strategy.Kinde.OAuthTest do
  use ExUnit.Case, async: true

  alias Ueberauth.Strategy.Kinde.OAuth

  defmodule MyApp.Kinde do
    def client_secret(_opts), do: "custom_client_secret"
  end

  describe "client/1" do
    test "uses client secret in the config when it is not a tuple" do
      # Set up test configuration
      Application.put_env(:ueberauth, Ueberauth.Strategy.Kinde.OAuth,
        client_id: "test_client_id",
        client_secret: "test_client_secret",
        domain: "https://test.kinde.com"
      )

      client = OAuth.client()
      assert client.client_secret == "test_client_secret"
      assert client.client_id == "test_client_id"
      assert client.site == "https://test.kinde.com"
    end

    test "generates client secret when it is using a tuple config" do
      options = [client_secret: {MyApp.Kinde, :client_secret}]
      assert %OAuth2.Client{client_secret: "custom_client_secret"} = OAuth.client(options)
    end

    test "sets site from domain option" do
      options = [domain: "https://test.kinde.com"]
      client = OAuth.client(options)
      assert client.site == "https://test.kinde.com"
    end

    test "uses site from config when domain is not provided" do
      # Set up test configuration
      Application.put_env(:ueberauth, Ueberauth.Strategy.Kinde.OAuth,
        site: "https://config.kinde.com"
      )

      client = OAuth.client()
      assert client.site == "https://config.kinde.com"
    end
  end
end

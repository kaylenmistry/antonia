defmodule Antonia.Services.Kinde.PortalTest do
  use Antonia.DataCase, async: false

  import Mock
  import Plug.Conn, only: [send_resp: 3, get_req_header: 2, put_resp_header: 3]

  alias Antonia.Services.Kinde.Portal

  setup do
    {:ok, bypass: Bypass.open(port: 8080)}
  end

  describe "generate_link/2" do
    test "should handle successful portal link generation", %{bypass: bypass} do
      access_token = "test-access-token"
      expected_url = "https://test.kinde.com/portal/profile"

      Bypass.expect_once(bypass, "GET", "/account_api/v1/portal_link", fn conn ->
        # Verify headers are correctly set
        assert ["Bearer test-access-token"] == get_req_header(conn, "authorization")

        # Verify query parameters
        assert conn.query_params["sub_nav"] == "profile"

        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(:ok, Jason.encode!(%{"url" => expected_url}))
      end)

      with_mock Antonia.Services.Kinde, config: fn -> %{domain: "http://localhost:8080"} end do
        assert {:ok, ^expected_url} = Portal.generate_link(access_token, sub_nav: :profile)
      end
    end

    test "should handle organization billing portal link generation", %{bypass: bypass} do
      access_token = "test-access-token"
      expected_url = "https://test.kinde.com/portal/organization/billing"

      Bypass.expect_once(bypass, "GET", "/account_api/v1/portal_link", fn conn ->
        # Verify headers are correctly set
        assert ["Bearer test-access-token"] == get_req_header(conn, "authorization")

        # Verify query parameters
        assert conn.query_params["sub_nav"] == "organization_billing"

        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(:ok, Jason.encode!(%{"url" => expected_url}))
      end)

      with_mock Antonia.Services.Kinde, config: fn -> %{domain: "http://localhost:8080"} end do
        assert {:ok, ^expected_url} =
                 Portal.generate_link(access_token, sub_nav: :organization_billing)
      end
    end

    test "should handle portal link generation with return_url", %{bypass: bypass} do
      access_token = "test-access-token"
      return_url = "https://example.com/app"
      expected_url = "https://test.kinde.com/portal/profile"

      Bypass.expect_once(bypass, "GET", "/account_api/v1/portal_link", fn conn ->
        # Verify headers are correctly set
        assert ["Bearer test-access-token"] == get_req_header(conn, "authorization")

        # Verify query parameters
        assert conn.query_params["sub_nav"] == "profile"
        assert conn.query_params["return_url"] == return_url

        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(:ok, Jason.encode!(%{"url" => expected_url}))
      end)

      with_mock Antonia.Services.Kinde, config: fn -> %{domain: "http://localhost:8080"} end do
        assert {:ok, ^expected_url} =
                 Portal.generate_link(access_token, sub_nav: :profile, return_url: return_url)
      end
    end

    @tag :capture_log
    test "should handle API error responses", %{bypass: bypass} do
      access_token = "test-access-token"

      Bypass.expect_once(bypass, "GET", "/account_api/v1/portal_link", fn conn ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      with_mock Antonia.Services.Kinde, config: fn -> %{domain: "http://localhost:8080"} end do
        assert {:error, :failed_to_generate_portal_link} =
                 Portal.generate_link(access_token, sub_nav: :profile)
      end
    end

    @tag :capture_log
    test "should handle network errors", %{bypass: bypass} do
      access_token = "test-access-token"

      Bypass.down(bypass)

      with_mock Antonia.Services.Kinde, config: fn -> %{domain: "http://localhost:8080"} end do
        assert {:error, :failed_to_generate_portal_link} =
                 Portal.generate_link(access_token, sub_nav: :profile)
      end
    end
  end
end

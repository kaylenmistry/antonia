defmodule Antonia.Services.Kinde.CreateOrganisationTest do
  use Antonia.DataCase, async: false

  import Mock
  import Plug.Conn, only: [send_resp: 3, get_req_header: 2, put_resp_header: 3]

  alias Antonia.Services.Kinde.CreateOrganisation

  setup do
    {:ok, bypass: Bypass.open(port: 8080)}
  end

  describe "create_organisation/2" do
    test "should handle successful organisation creation", %{bypass: bypass} do
      access_token = "test-access-token"
      organisation_params = %{name: "Test Organisation", description: "A test organisation"}

      expected_response = %{
        "organization" => %{
          "id" => "org_123",
          "name" => "Test Organisation",
          "code" => "org_test_organisation",
          "description" => "A test organisation"
        }
      }

      Bypass.expect_once(bypass, "POST", "/api/v1/organizations", fn conn ->
        # Verify headers are correctly set
        assert ["Bearer test-access-token"] == get_req_header(conn, "authorization")

        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(:ok, Jason.encode!(expected_response))
      end)

      with_mock Antonia.Services.Kinde, config: fn -> %{domain: "http://localhost:8080"} end do
        assert {:ok, "org_test_organisation"} =
                 CreateOrganisation.create_organisation(access_token, organisation_params)
      end
    end

    test "should handle organisation creation with minimal params", %{bypass: bypass} do
      access_token = "test-access-token"
      organisation_params = %{name: "Minimal Org"}

      expected_response = %{
        "organization" => %{
          "id" => "org_456",
          "name" => "Minimal Org",
          "code" => "org_minimal_org",
          "description" => ""
        }
      }

      Bypass.expect_once(bypass, "POST", "/api/v1/organizations", fn conn ->
        assert ["Bearer test-access-token"] == get_req_header(conn, "authorization")

        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(:ok, Jason.encode!(expected_response))
      end)

      with_mock Antonia.Services.Kinde, config: fn -> %{domain: "http://localhost:8080"} end do
        assert {:ok, "org_minimal_org"} =
                 CreateOrganisation.create_organisation(access_token, organisation_params)
      end
    end

    @tag :capture_log
    test "should handle API error responses", %{bypass: bypass} do
      access_token = "test-access-token"
      organisation_params = %{name: "Test Organisation"}

      Bypass.expect_once(bypass, "POST", "/api/v1/organizations", fn conn ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(400, Jason.encode!(%{"error" => "Invalid organisation data"}))
      end)

      with_mock Antonia.Services.Kinde, config: fn -> %{domain: "http://localhost:8080"} end do
        assert {:error, :failed_to_create_organisation} =
                 CreateOrganisation.create_organisation(access_token, organisation_params)
      end
    end

    @tag :capture_log
    test "should handle network errors", %{bypass: bypass} do
      access_token = "test-access-token"
      organisation_params = %{name: "Test Organisation"}

      Bypass.down(bypass)

      with_mock Antonia.Services.Kinde, config: fn -> %{domain: "http://localhost:8080"} end do
        assert {:error, :failed_to_create_organisation} =
                 CreateOrganisation.create_organisation(access_token, organisation_params)
      end
    end
  end
end

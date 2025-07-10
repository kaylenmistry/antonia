defmodule AntoniaWeb.HealthTest do
  use AntoniaWeb.ConnCase

  import Mock
  import Plug.Test

  alias Antonia.Health
  alias AntoniaWeb.O11Y.Endpoint
  alias AntoniaWeb.O11Y.Health, as: HealthPlug

  @opts Endpoint.init([])

  describe "/health/liveness" do
    test "returns 200 if app is alive" do
      conn =
        :get
        |> conn("/health/liveness")
        |> Endpoint.call(@opts)

      assert conn.status == 200
    end

    test "returns 503 if app is not alive" do
      with_mock Health, [:passthrough], alive?: fn -> false end do
        conn =
          :get
          |> conn("/health/liveness")
          |> Endpoint.call(@opts)

        assert conn.status == 503
      end
    end
  end

  describe "/health/readiness" do
    test "returns 200 if all migrations are done" do
      conn =
        :get
        |> conn("/health/readiness")
        |> Endpoint.call(@opts)

      assert conn.status == 200
    end

    test "returns 503 if not all migrations are up" do
      with_mock Health, [:passthrough], ready?: fn -> false end do
        conn =
          :get
          |> conn("/health/readiness")
          |> Endpoint.call(@opts)

        assert conn.status == 503
      end
    end
  end

  test "returns conn unchanged if path is not a health check" do
    conn = HealthPlug.call(build_conn(), [])

    refute conn.halted
  end

  test "returns 404 on all other paths" do
    conn =
      :get
      |> conn("/health/other")
      |> Endpoint.call(@opts)

    assert conn.status == 404
  end
end

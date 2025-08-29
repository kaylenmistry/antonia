defmodule AntoniaApp.PromExTest do
  use ExUnit.Case

  import Plug.Test

  @opts PromEx.Plug.init(prom_ex_module: AntoniaApp.PromEx)

  @plugin_identifiers [
    "antonia_prom_ex_beam_system",
    "antonia_prom_ex_ecto",
    "antonia_prom_ex_application",
    "antonia_prom_ex_phoenix"
  ]

  describe "/metrics" do
    test "returns metrics for beam, application, phoenix and ecto plugins" do
      conn =
        :get
        |> conn("/metrics")
        |> PromEx.Plug.call(@opts)

      assert conn.status == 200
      assert String.contains?(conn.resp_body, @plugin_identifiers)
    end
  end
end

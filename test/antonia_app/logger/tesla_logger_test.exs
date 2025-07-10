defmodule AntoniaApp.Logger.TeslaLoggerTest do
  use AntoniaWeb.ConnCase, async: false

  import Mock

  alias AntoniaApp.Logger.TeslaLogger

  @metadata %{
    env: %Tesla.Env{
      body: %{
        name: "My new company"
      },
      headers: [{"content-type", "application/json"}],
      method: :post,
      opts: [],
      query: [{"merchant_id", "420"}],
      status: 500,
      url: "https://merchant-data.salt/api/merchant"
    }
  }

  describe "tesla_request_stop/4" do
    setup do
      level = Application.get_env(:logger, :level)
      Logger.configure(level: :all)

      on_exit(fn ->
        Logger.configure(level: level)
      end)
    end

    @tag :capture_log
    test "logs the result of the request with all relevant metadata" do
      duration_us = System.convert_time_unit(20_000, :native, :microsecond)
      pid = self()

      with_mock Antonia.TestLoggerBackend.ToMock,
        log: fn :info, msg, _ts, metadata ->
          send(pid, {msg, Map.new(metadata)})
        end do
        TeslaLogger.tesla_request_stop(
          %{},
          %{duration: 20_000},
          @metadata,
          %{}
        )

        assert_receive {"post https://merchant-data.salt/api/merchant -> 500",
                        %{
                          duration: ^duration_us,
                          headers: [{"content-type", "application/json"}],
                          opts: [],
                          query: [{"merchant_id", "420"}]
                        } = received_metadata}

        refute Map.has_key?(received_metadata, :body)
      end
    end
  end

  describe "install/4" do
    test "tesla_request_stop telemetry callback is attached to telemetry events" do
      handler =
        Enum.filter(:telemetry.list_handlers([:tesla, :request]), fn x ->
          x.event_name == [:tesla, :request, :stop]
        end)

      assert handler == [
               %{
                 config: :ok,
                 event_name: [:tesla, :request, :stop],
                 function: &TeslaLogger.tesla_request_stop/4,
                 id: {TeslaLogger, [:tesla, :request, :stop]}
               }
             ]
    end
  end
end

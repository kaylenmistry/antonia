defmodule AntoniaApp.Logger.PhoenixLoggerTest do
  use AntoniaWeb.ConnCase, async: false

  import Mock

  alias AntoniaApp.Logger.PhoenixLogger

  @metadata %{
    conn: %{status: 200, method: "GET", params: %{}},
    route: "/login"
  }

  setup do
    level = Application.get_env(:logger, :level)
    Logger.configure(level: :all)

    on_exit(fn ->
      Logger.configure(level: level)
    end)
  end

  describe "phoenix_router_dispatch_stop/4" do
    @tag :capture_log
    test "logs the result of the request with all relevant metadata" do
      duration_us = System.convert_time_unit(20_000_000, :native, :microsecond)
      pid = self()

      with_mock Antonia.TestLoggerBackend.ToMock,
        log: fn :info, msg, _ts, metadata ->
          send(pid, {msg, Map.new(metadata)})
        end do
        PhoenixLogger.phoenix_router_dispatch_stop(
          %{},
          %{duration: 20_000_000},
          @metadata,
          %{}
        )

        assert_receive {"GET /login -> 200",
                        %{
                          duration_us: ^duration_us,
                          route: "/login",
                          method: "GET",
                          status: 200
                        }}
      end
    end
  end

  describe "phoenix_channel_joined/4" do
    @tag :capture_log
    test "logs the result of the request with all relevant metadata" do
      duration_us = System.convert_time_unit(20_000_000, :native, :microsecond)
      pid = self()

      with_mock Antonia.TestLoggerBackend.ToMock,
        log: fn :info, msg, _ts, metadata ->
          send(pid, {msg, Map.new(metadata)})
        end do
        PhoenixLogger.phoenix_channel_joined(
          %{},
          %{duration: 20_000_000},
          %{socket: %{topic: "user"}, result: :ok},
          %{}
        )

        assert_receive {"JOINED user",
                        %{
                          duration_us: ^duration_us,
                          socket_topic: "user"
                        }}
      end
    end

    @tag :capture_log
    test "logs the result of the failed request with all relevant metadata" do
      duration_us = System.convert_time_unit(20_000_000, :native, :microsecond)
      pid = self()

      with_mock Antonia.TestLoggerBackend.ToMock,
        log: fn :info, msg, _ts, metadata ->
          send(pid, {msg, Map.new(metadata)})
        end do
        PhoenixLogger.phoenix_channel_joined(
          %{},
          %{duration: 20_000_000},
          %{socket: %{topic: "user"}, result: :error},
          %{}
        )

        assert_receive {"REFUSED JOIN user",
                        %{
                          duration_us: ^duration_us,
                          socket_topic: "user"
                        }}
      end
    end
  end

  describe "phoenix_channel_handled_in/4" do
    @tag :capture_log
    test "logs the result of the request with all relevant metadata" do
      duration_us = System.convert_time_unit(20_000_000, :native, :microsecond)
      pid = self()

      with_mock Antonia.TestLoggerBackend.ToMock,
        log: fn :info, msg, _ts, metadata ->
          send(pid, {msg, Map.new(metadata)})
        end do
        PhoenixLogger.phoenix_channel_handled_in(
          %{},
          %{duration: 20_000_000},
          %{socket: %{topic: "user", channel: :some_channel}, event: "update"},
          %{}
        )

        assert_receive {"HANDLED update INCOMING ON user (:some_channel)",
                        %{
                          duration_us: ^duration_us,
                          socket_topic: "user"
                        }}
      end
    end
  end

  describe "install/4" do
    test "router_dispatch_stop telemetry callback is attached to telemetry events" do
      handler_events = [
        [:phoenix, :router_dispatch, :stop],
        [:phoenix, :channel_joined],
        [:phoenix, :channel_handled_in]
      ]

      handlers =
        Enum.filter(:telemetry.list_handlers([:phoenix]), fn handler ->
          Enum.member?(handler_events, handler.event_name) &&
            AntoniaApp.Logger.PhoenixLogger == elem(handler.id, 0)
        end)

      assert %{
               config: :ok,
               event_name: [:phoenix, :router_dispatch, :stop],
               function: &PhoenixLogger.phoenix_router_dispatch_stop/4,
               id: {PhoenixLogger, [:phoenix, :router_dispatch, :stop]}
             } in handlers

      assert %{
               config: :ok,
               event_name: [:phoenix, :channel_joined],
               function: &PhoenixLogger.phoenix_channel_joined/4,
               id: {PhoenixLogger, [:phoenix, :channel_joined]}
             } in handlers

      assert %{
               config: :ok,
               event_name: [:phoenix, :channel_handled_in],
               function: &PhoenixLogger.phoenix_channel_handled_in/4,
               id: {PhoenixLogger, [:phoenix, :channel_handled_in]}
             } in handlers
    end
  end
end

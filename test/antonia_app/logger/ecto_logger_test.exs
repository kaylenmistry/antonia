defmodule AntoniaApp.Logger.EctoLoggerTest do
  @moduledoc false
  use ExUnit.Case

  import Mock

  alias AntoniaApp.Logger.EctoLogger

  setup do
    level = Application.get_env(:logger, :level)
    Logger.configure(level: :all)

    on_exit(fn ->
      Logger.configure(level: level)
    end)

    measurements = %{
      decode_time: 1_682_944,
      idle_time: 818_112_726,
      query_time: 644_060,
      queue_time: 821_246,
      total_time: 3_148_250
    }

    converted_measurements =
      Map.new(
        for {key, time} <- measurements do
          {key, System.convert_time_unit(time, :native, :microsecond)}
        end
      )

    [measurements: measurements, converted_measurements: converted_measurements]
  end

  describe "handle_event/4 for success" do
    setup do
      metadata = %{
        query: "SELECT u0.\"id\" FROM \"users\" AS u0",
        result:
          {:ok,
           %Postgrex.Result{
             command: :select,
             num_rows: 0,
             rows: []
           }},
        source: "users",
        type: :ecto_sql_query
      }

      [metadata: metadata]
    end

    @tag :capture_log
    test "handles ecto result when is ok", %{
      metadata: metadata,
      converted_measurements: converted_measurements,
      measurements: measurements
    } do
      pid = self()

      %{
        idle_time: idle_time,
        decode_time: decode_time,
        query_time: query_time,
        queue_time: queue_time,
        total_time: total_time
      } = converted_measurements

      with_mock Antonia.TestLoggerBackend.ToMock,
        log: fn :debug, msg, _ts, metadata ->
          send(pid, {msg, Map.new(metadata)})
        end do
        EctoLogger.handle_event([:antonia, :repo, :query], measurements, metadata, %{})

        assert_receive {"SQL Query Success",
                        %{
                          idle_time: ^idle_time,
                          total_time: ^total_time,
                          query_time: ^query_time,
                          queue_time: ^queue_time,
                          decode_time: ^decode_time,
                          command: :select,
                          num_rows: 0,
                          source: "users"
                        }}
      end
    end
  end

  describe "handle_event/4 for error" do
    setup do
      metadata = %{
        query: "",
        result:
          {:error,
           %Postgrex.Error{
             connection_id: 3838,
             message: nil,
             postgres: %{
               code: :undefined_column,
               routine: "errorMissingColumn",
               severity: "ERROR",
               unknown: "ERROR"
             },
             query: "UPDATE users SET locale = 'oo' WHERE emailx = 'demo@example.com'"
           }},
        source: "users",
        type: :ecto_sql_query
      }

      [metadata: metadata]
    end

    @tag :capture_log
    test "include error logs when doing a sql query", %{
      converted_measurements: converted_measurements,
      measurements: measurements,
      metadata: metadata
    } do
      pid = self()

      %{
        idle_time: idle_time,
        decode_time: decode_time,
        query_time: query_time,
        queue_time: queue_time,
        total_time: total_time
      } = converted_measurements

      with_mock Antonia.TestLoggerBackend.ToMock,
        log: fn :error, msg, _ts, metadata ->
          send(pid, {msg, Map.new(metadata)})
        end do
        EctoLogger.handle_event([:antonia, :repo, :query], measurements, metadata, %{})

        assert_receive {"SQL Query Error",
                        %{
                          idle_time: ^idle_time,
                          total_time: ^total_time,
                          query_time: ^query_time,
                          queue_time: ^queue_time,
                          decode_time: ^decode_time,
                          severity: "ERROR",
                          routine: "errorMissingColumn",
                          code: :undefined_column,
                          source: "users"
                        }}
      end
    end
  end
end

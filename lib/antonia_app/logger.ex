defmodule AntoniaApp.Logger do
  @moduledoc """
  Main custom logger for telemetry. It can listen for telemetry events of
  :telemetry module. To run a new logger and start listening for events, we do:

      defmodule AntoniaApp.Logger.MyCustomLogger
        def start do
          :ok = :telemetry.attach(
              "antonia",
              [:my_mod, :my_func],
              &handle_event/4,
              %{}
            )
        end

        def handle_event([:my_mod, :my_func], measurements, metadata, config) do
          # ...
        end
      end

  After that, we can start send events just by using `:telemetry.execute/3`.

      :telemetry.execute(
        [:my_mod, :my_func],
        %{latency: latency},
        %{request_path: path, status_code: status}
      )

  More info about how we're using telemetry, can be found at: https://hexdocs.pm/telemetry/readme.html
  """

  alias AntoniaApp.Logger.EctoLogger
  alias AntoniaApp.Logger.PhoenixLogger
  alias AntoniaApp.Logger.TeslaLogger

  @doc """
  Start listening for custom telemetry that we've set before. Here, we just
  start the main function to start listening for telemetry events. This function
  is called whenever the app is up, so make sure you custom telemetry logger is
  set here.
  """
  @spec start :: :ok
  def start do
    EctoLogger.start()
    PhoenixLogger.start()
    TeslaLogger.start()

    :ok
  end
end

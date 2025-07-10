defmodule Antonia.DevLoggerFileBackend do
  @moduledoc """
  Custom Elixir logger backend for writting logs locally to file in local development environment. Using [this](https://github.com/onkel-dirtus/logger_file_backend) as a base implementation/
  This library used `IO.write()` to write the logs to file. As a result Docker for Mac did not
  notify the containers of the flush event for the log file, resulting in the updated logs not showing in Grafana.
  We created this file as a simple alternative that works in our local development environment. It should NOT be used in production.
  """

  @behaviour :gen_event

  @type path :: String.t()
  @type format :: String.t()
  @type level :: Logger.level()

  @default_format "$time $metadata[$level] $message\n"

  @doc """
  Inits the logger backend.
  """
  @spec init(tuple()) :: {:ok, map()}
  def init({__MODULE__, name}) do
    {:ok, configure(name, [])}
  end

  @doc """
  Sets up the state of the backend of the logger
  """
  @spec handle_call(tuple(), map()) :: {:ok, :ok, map()}
  def handle_call({:configure, opts}, %{name: name} = state) do
    {:ok, :ok, configure(name, opts, state)}
  end

  def handle_call(:path, %{path: path} = state) do
    {:ok, {:ok, path}, state}
  end

  @doc """
  Handles the log events saving to a file if the respective logging level is enabled
  """
  @spec handle_event(any(), map()) :: {:ok, map()}
  def handle_event(
        {level, _gl, {Logger, msg, ts, md}},
        %{level: min_level} = state
      ) do
    if is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt do
      log_event(level, msg, ts, md, state)
    else
      {:ok, state}
    end
  end

  def handle_event(:flush, state) do
    {:ok, state}
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  @spec log_event(atom(), String.t(), tuple(), [Keyword.t()], map()) :: {:ok, map()}
  defp log_event(_level, _msg, _ts, _md, %{path: nil} = state) do
    {:ok, state}
  end

  # sobelow_skip ["Traversal"]
  defp log_event(level, msg, ts, md, %{path: path} = state) when is_binary(path) do
    output = format_event(level, msg, ts, md, state)
    File.write!(path, output, [:append])
    {:ok, state}
  end

  @spec format_event(atom(), String.t(), tuple(), [Keyword.t()], map()) :: String.t()
  defp format_event(level, msg, ts, md, %{format: format}) do
    Logger.Formatter.format(format, level, msg, ts, md)
  end

  @spec configure(any(), [Keyword.t()]) :: map()
  defp configure(name, opts) do
    state = %{
      name: nil,
      path: nil,
      format: nil,
      level: nil
    }

    configure(name, opts, state)
  end

  @spec configure(any(), [Keyword.t()], map()) :: map()
  defp configure(name, opts, state) do
    env = Application.get_env(:logger, name, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, name, opts)

    level = Keyword.get(opts, :level)
    format_opts = Keyword.get(opts, :format, @default_format)
    format = Logger.Formatter.compile(format_opts)
    path = Keyword.get(opts, :path)

    %{
      state
      | name: name,
        path: path,
        format: format,
        level: level
    }
  end
end

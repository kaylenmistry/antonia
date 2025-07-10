defmodule Antonia.TestLoggerBackend do
  @moduledoc """
  This backend doesn't do anything, but allow us to mock it.
  """

  @behaviour :gen_event

  defmodule ToMock do
    @moduledoc false

    @spec log(atom(), String.t(), tuple(), Keyword.t()) :: any()
    def log(_level, _msg, _ts, _metadata) do
      nil
    end
  end

  @doc false
  @spec init(tuple()) :: {:ok, map()}
  def init(_) do
    {:ok, %{}}
  end

  @doc false
  @spec handle_call(tuple(), map()) :: {:ok, :ok, map()}
  def handle_call({:configure, _}, state) do
    {:ok, :ok, state}
  end

  @doc false
  @spec handle_event(any(), map()) :: {:ok, map()}
  def handle_event(
        {level, _gl, {Logger, msg, ts, md}},
        state
      ) do
    ToMock.log(level, msg, ts, md)

    {:ok, state}
  end

  def handle_event(:flush, state) do
    {:ok, state}
  end

  def handle_info(_, state) do
    {:ok, state}
  end
end

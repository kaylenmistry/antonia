defmodule AntoniaApp.Config do
  @moduledoc """
  Helpers for loading configuration from environment variables when booting the application.
  """

  @doc "Get environment variable as string"
  if Mix.env() == :prod do
    @spec get_string(String.t(), String.t()) :: String.t()
    def get_string(key, _default \\ nil) do
      with nil <- System.get_env(key) do
        raise """
        Environment variable #{key} is missing.
        All configuration environment variables should be set in production.
        """
      end
    end
  else
    @spec get_string(String.t(), String.t() | nil) :: String.t() | nil
    def get_string(key, default \\ nil) do
      case System.get_env(key) do
        nil ->
          default

        value ->
          value
      end
    end
  end

  @doc "Get environment variable as integer"
  @spec get_integer(String.t(), integer()) :: integer()
  def get_integer(key, default) do
    case get_string(key) do
      nil -> default
      str -> String.to_integer(str)
    end
  end

  @doc "Get environment variable as a URI"
  @spec get_uri(String.t(), URI.t() | String.t()) :: URI.t()
  def get_uri(key, default) do
    case {default, get_string(key)} do
      {%URI{} = default, nil} -> default
      {default, nil} -> URI.parse(default)
      {_, str} -> URI.parse(str)
    end
  end

  @doc """
  Get environment variable and parse it as boolean.

  It will be `true` if the value is `"true"` and will be false otherwise.

  ## Examples

      iex> System.put_env("MY_ENV", "true")
      iex> get_boolean("MY_ENV")
      true

      iex> System.put_env("MY_ENV", "false")
      iex> get_boolean("MY_ENV")
      false

      iex> System.put_env("MY_ENV", "anything")
      iex> get_boolean("MY_ENV")
      false

      iex> System.delete_env("MY_ENV")
      iex> get_boolean("MY_ENV")
      false

      iex> System.delete_env("MY_ENV")
      iex> get_boolean("MY_ENV", true)
      true
  """
  @spec get_boolean(String.t(), boolean()) :: boolean()
  def get_boolean(key, default \\ false) do
    case get_string(key) do
      nil ->
        default

      value ->
        value == "true"
    end
  end

  @doc "Forms the Postgres database URL from the JSON database credentials."
  @spec get_database_url(String.t()) :: String.t()
  def get_database_url(default) do
    with nil <- System.get_env("DATABASE_URL") do
      "DATABASE_CREDENTIALS"
      |> get_string()
      |> parse_database_url(default)
    end
  end

  @spec parse_database_url(String.t() | nil, String.t()) :: String.t()
  defp parse_database_url(nil, default), do: default

  defp parse_database_url(value, _default) do
    case Jason.decode(value) do
      {:ok,
       %{
         "dbname" => db_name,
         "engine" => engine,
         "host" => host,
         "port" => port,
         "username" => username,
         "password" => password
       }} ->
        "#{engine}://#{username}:#{password}@#{host}:#{port}/#{db_name}?ssl=true&sslmode=require"

      _ ->
        raise """
        Invalid database credentials format.
        The database credentials should be a JSON object with the following keys:
        - dbname
        - host
        - port
        - username
        - password
        """
    end
  end
end

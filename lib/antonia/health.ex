defmodule Antonia.Health do
  @moduledoc """
  Check various health attributes of the application
  """

  alias Antonia.Repo

  @doc "Are the service and it's dependencies loaded and connected and seemly working properly?"
  @spec alive?() :: boolean()
  def alive? do
    Repo.query!("SELECT 1").rows == [[1]]
  rescue
    _ -> false
  end

  @doc "Is the service ready to accept external traffic?"
  @spec ready?() :: boolean()
  def ready? do
    Repo
    |> Ecto.Migrator.migrations()
    |> Enum.all?(&match?({:up, _, _}, &1))
  end
end

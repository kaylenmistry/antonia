defmodule Antonia.Enums.EmailStatus do
  @moduledoc "Email statuses."

  @statuses [:pending, :sent, :failed]

  @doc """
  Returns all different statuses of emails.

  ## Examples
      iex> Antonia.Enums.EmailStatus.values()
      [:pending, :sent, :failed]
  """
  @spec values :: [atom()]
  def values, do: @statuses
end

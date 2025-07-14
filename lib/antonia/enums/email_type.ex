defmodule Antonia.Enums.EmailType do
  @moduledoc "Email types."

  @types [:monthly_reminder, :overdue_reminder, :submission_receipt]

  @doc """
  Returns all different types of emails.

  ## Examples
      iex> Antonia.Enums.EmailType.values()
      [:monthly_reminder, :overdue_reminder, :submission_receipt]
  """
  @spec values :: [atom()]
  def values, do: @types
end

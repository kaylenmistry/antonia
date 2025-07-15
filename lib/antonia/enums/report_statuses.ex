defmodule Antonia.Enums.ReportStatus do
  @moduledoc "Report statuses."

  @statuses [:pending, :submitted, :approved, :rejected]

  @doc """
  Returns all different statuses of reports.

  ## Examples
      iex> Antonia.Enums.ReportStatus.values()
      [:pending, :submitted, :approved, :rejected]
  """
  @spec values :: [atom()]
  def values, do: @statuses
end

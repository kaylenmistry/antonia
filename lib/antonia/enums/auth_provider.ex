defmodule Antonia.Enums.AuthProvider do
  @moduledoc "Auth providers."

  @providers [
    :kinde
  ]

  @doc """
  Returns the list of all auth providers.

  ## Examples
      iex> AuthProvider.values()
      [:kinde]
  """
  def values, do: @providers
end

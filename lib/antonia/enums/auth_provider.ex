defmodule Antonia.Enums.AuthProvider do
  @moduledoc "Auth providers."

  @providers [
    :google,
    :kinde
  ]

  @doc """
  Returns the list of all auth providers.

  ## Examples
      iex> AuthProvider.values()
      [:kinde, :google]
  """
  def values, do: @providers
end

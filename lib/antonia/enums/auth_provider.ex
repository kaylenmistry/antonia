defmodule Antonia.Enums.AuthProvider do
  @moduledoc "Auth providers."

  @providers [
    :google,
    :apple
  ]

  @doc """
  Returns the list of all auth providers.

  ## Examples
      iex> AuthProvider.values()
      [:google, :apple]
  """
  def values, do: @providers
end

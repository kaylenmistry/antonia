defmodule AntoniaWeb.FormHelpers do
  @moduledoc """
  Helpers for working with forms.
  """

  @doc """
  Formats the params from a form to be used in a changeset.
  This includes converting the keys to atoms recursively, ignoring any keys that are not existing atoms.

  ## Examples

      iex> format_params([])
      []
      iex> format_params(%{"non_existent_atom" => "foo"})
      %{}
      iex> format_params(%{"name" => "foo"})
      %{name: "foo"}
      iex> format_params(%{"group" => %{"name" => "foo"}})
      %{group: %{name: "foo"}}
      iex> format_params(%{"items" => [%{"name" => "item1"}]})
      %{items: [%{name: "item1"}]}
      iex> format_params(%{name: "foo"})
      %{name: "foo"}
      iex> format_params([%{name: "foo"}])
      [%{name: "foo"}]
  """
  @spec format_params(map() | list()) :: map() | list()
  def format_params(params) when is_list(params), do: Enum.map(params, &format_params/1)

  def format_params(params) do
    params
    |> Enum.map(&transform_key_and_value/1)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  @spec transform_key_and_value({String.t(), any()}) :: {atom(), any()} | nil
  defp transform_key_and_value({k, v}) do
    case safe_to_atom(k) do
      nil -> nil
      key -> {key, transform_value(v)}
    end
  end

  @spec transform_value(any()) :: any()
  defp transform_value(v) when is_list(v), do: Enum.map(v, &format_params/1)
  defp transform_value(v) when is_map(v), do: format_params(v)
  defp transform_value(v), do: v

  @spec safe_to_atom(String.t()) :: atom() | nil
  defp safe_to_atom(key) when is_atom(key), do: key

  defp safe_to_atom(key) do
    String.to_existing_atom(key)
  rescue
    _ -> nil
  end
end

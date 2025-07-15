defmodule Antonia.Schema do
  @moduledoc """
  A macro to set the defaults of our Ecto Schemas.

  We use:
  - TypedEctoSchema for automatically generating some helper `t()` types
  - Uniq to be able to use UUIDv7 by default
  """

  defmacro __using__(_) do
    quote do
      use TypedEctoSchema
      @primary_key {:id, Uniq.UUID, version: 7, autogenerate: true}
      @foreign_key_type Uniq.UUID
    end
  end
end

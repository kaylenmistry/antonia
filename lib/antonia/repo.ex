defmodule Antonia.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :antonia,
    adapter: Ecto.Adapters.Postgres
end

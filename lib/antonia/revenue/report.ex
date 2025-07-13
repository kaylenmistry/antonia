defmodule Antonia.Revenue.Report do
  @moduledoc false
  use Antonia.Schema

  import Ecto.Changeset

  alias Antonia.Revenue.Store

  @fields [
    :status,
    :currency,
    :revenue,
    :period_start,
    :period_end,
    :store_id
  ]

  @required_fields @fields

  typed_schema "reports" do
    field(:status, :string)
    field(:currency, :string)
    field(:revenue, :decimal)
    field(:period_start, :date)
    field(:period_end, :date)

    belongs_to(:store, Store)

    timestamps()
  end

  @doc "Changeset for reports"
  @spec changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  def changeset(report, attrs) do
    report
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_number(:revenue, greater_than: 0)
    |> validate_period_dates()
    |> foreign_key_constraint(:store_id)
  end

  defp validate_period_dates(changeset) do
    start_date = get_field(changeset, :period_start)
    end_date = get_field(changeset, :period_end)

    if start_date && end_date && Date.compare(start_date, end_date) == :gt do
      add_error(changeset, :period_end, "must be after period start")
    else
      changeset
    end
  end
end

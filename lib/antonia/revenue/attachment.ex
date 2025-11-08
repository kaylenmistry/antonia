defmodule Antonia.Revenue.Attachment do
  @moduledoc false
  use Antonia.Schema

  import Ecto.Changeset

  alias Antonia.Revenue.Attachment
  alias Antonia.Revenue.Report

  @fields [
    :s3_key,
    :filename,
    :file_type,
    :file_size,
    :metadata,
    :report_id
  ]

  @required_fields [
    :s3_key,
    :filename,
    :file_type,
    :report_id
  ]

  typed_schema "attachments" do
    field(:s3_key, :string)
    field(:filename, :string)
    field(:file_type, :string)
    field(:file_size, :integer)
    field(:metadata, :map)

    belongs_to(:report, Report)

    timestamps()
  end

  @doc "Changeset for attachments"
  @spec changeset(Attachment.t(), map()) :: Ecto.Changeset.t()
  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:report_id)
  end

  @doc "Changeset for attachments when used with cast_assoc (report_id will be set automatically)"
  @spec changeset_for_assoc(Attachment.t(), map()) :: Ecto.Changeset.t()
  def changeset_for_assoc(attachment, attrs) do
    attachment
    |> cast(attrs, @fields)
    |> validate_required([:s3_key, :filename, :file_type])
    |> foreign_key_constraint(:report_id)
  end
end

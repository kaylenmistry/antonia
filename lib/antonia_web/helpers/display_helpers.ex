defmodule AntoniaWeb.DisplayHelpers do
  @moduledoc """
  Shared helper functions for formatting and displaying data in views.
  """

  @doc """
  Formats a currency amount with the appropriate symbol.

  ## Examples

      iex> format_currency(1234.56, "EUR")
      "€1,234.56"

      iex> format_currency(1000.0, "USD")
      "$1,000.00"

      iex> format_currency(500.5, "AUD")
      "A$500.50"
  """
  @spec format_currency(number(), String.t()) :: String.t()
  def format_currency(amount, currency) when is_number(amount) do
    currency = currency || "EUR"
    amount = :erlang.float_to_binary(amount * 1.0, decimals: 2)
    amount = String.replace(amount, ~r/\B(?=(\d{3})+(?!\d))/, ",")

    symbol =
      case currency do
        "EUR" -> "€"
        "AUD" -> "A$"
        "USD" -> "$"
        _ -> currency
      end

    "#{symbol}#{amount}"
  end

  def format_currency(amount, _) when is_number(amount), do: format_currency(amount, "EUR")
  def format_currency(_, _), do: "€0"

  @doc """
  Formats a number for use in input fields, avoiding scientific notation.

  ## Examples

      iex> format_number_for_input(1234.56)
      "1234.56"

      iex> format_number_for_input(1000.0)
      "1000.0"

      iex> format_number_for_input(10000.5)
      "10000.5"
  """
  @spec format_number_for_input(number() | nil) :: String.t()
  def format_number_for_input(nil), do: ""
  def format_number_for_input(amount) when is_number(amount) do
    # Use :io_lib.format to avoid scientific notation, always show 2 decimal places for currency
    :io_lib.format("~.2f", [amount * 1.0]) |> List.to_string()
  end
  def format_number_for_input(_), do: ""

  @doc """
  Formats a date in a readable format.

  ## Examples

      iex> format_date(~D[2025-01-15])
      "January 15, 2025"
  """
  @spec format_date(Date.t()) :: String.t()
  def format_date(date) do
    Calendar.strftime(date, "%B %d, %Y")
  end

  @doc """
  Formats a timestamp in a readable format.

  ## Examples

      iex> format_timestamp(~U[2025-01-15 14:30:00Z])
      "January 15, 2025 at 02:30 PM"
  """
  @spec format_timestamp(DateTime.t() | NaiveDateTime.t()) :: String.t()
  def format_timestamp(%NaiveDateTime{} = datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  def format_timestamp(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  def format_timestamp(_), do: ""

  @doc """
  Builds a user-friendly error message from an Ecto changeset.

  ## Examples

      iex> changeset = %Ecto.Changeset{errors: [revenue: {"must be greater than 0", []}]}
      iex> build_error_message(changeset, "Failed to save")
      "Failed to save: revenue: must be greater than 0"
  """
  @spec build_error_message(Ecto.Changeset.t(), String.t()) :: String.t()
  def build_error_message(changeset, default_message \\ "Operation failed") do
    case changeset.errors do
      [] ->
        default_message

      errors ->
        error_details =
          Enum.map_join(errors, ", ", fn {field, {message, _}} ->
            "#{field}: #{message}"
          end)

        "#{default_message}: #{error_details}"
    end
  end
end

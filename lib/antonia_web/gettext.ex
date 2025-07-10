defmodule AntoniaWeb.Gettext do
  @moduledoc """
  A module providing Internationalization with a gettext-based API.

  By using [Gettext](https://hexdocs.pm/gettext),
  your module gains a set of macros for translations, for example:

      use Gettext, backend: AntoniaWeb.Gettext

      # Simple translation
      gettext("Here is the string to translate")

      # Plural translation
      ngettext("Here is the string to translate",
               "Here are the strings to translate",
               3)

      # Domain-based translation
      dgettext("errors", "Here is the error message to translate")

  See the [Gettext Docs](https://hexdocs.pm/gettext) for detailed usage.
  """
  use Gettext.Backend, otp_app: :antonia

  @locale_display_names %{
    "en" => "English",
    "pt" => "Português"
  }

  @doc """
  Retrieves the language display name given a locale id

  ### Parameters
    - locale: A string representing the locale id

  ### Examples
      iex> Gettext.get_display_name("en")
      "English"
  """
  @spec get_display_name(String.t()) :: String.t()
  def get_display_name(locale) do
    Map.get(@locale_display_names, locale, locale)
  end

  @doc """
  Returns the suported locales

  ### Examples
      iex> Gettext.get_supported_locales()
      [%{code: "en", name: "English"}, %{code: "pt", name: "Português"}]
  """
  def get_supported_locales do
    Enum.map(@locale_display_names, fn {k, v} -> %{code: k, name: v} end)
  end

  @doc """
  Helper function that returns true if the locale is supported, otherwise false.

  ### Parameters
    - locale: locale to check support for

  ### Examples
      iex> Gettext.known?("en")
      true
      iex> Gettext.known?("es")
      false
  """
  @spec known?(String.t()) :: boolean()
  def known?(locale) do
    locale in Gettext.known_locales(__MODULE__)
  end
end

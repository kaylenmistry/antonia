defmodule Antonia.Mailer.Notifier do
  @moduledoc """
  Delivers emails to users.
  """

  use Gettext, backend: AntoniaWeb.Gettext

  import Swoosh.Email

  require Logger

  alias Antonia.Mailer
  alias Antonia.Mailer.Emails

  @doc "Delivers the monthly reminder email to a recipient store"
  @spec deliver_monthly_reminder(term()) ::
          {:ok, Swoosh.Email.t()} | {:error, :missing_customer_email | term}
  def deliver_monthly_reminder(email) do
    store = test_store(email)
    subject = gettext("Revenue report due")

    deliver(:monthly_reminder, store.email, subject, %{store: store, period_start: "2025-01-01", period_end: "2025-01-31", base_url: base_url()})
  end

  @doc "Delivers the overdue reminder email to a recipient store"
  @spec deliver_overdue_reminder(term()) :: {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_overdue_reminder(email) do
    store = test_store(email)
    subject = gettext("REMINDER: Report revenue due")

    deliver(:overdue_reminder, store.email, subject, %{store: store, period_start: "2025-01-01", period_end: "2025-01-31", base_url: base_url()})
  end

  @doc "Delivers the submission receipt email to a recipient store"
  @spec deliver_submission_receipt(term()) :: {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_submission_receipt(email) do
    store = test_store(email)
    subject = gettext("Thank you")

    deliver(:submission_receipt, store.email, subject, %{store: store, period_start: "2025-01-01", period_end: "2025-01-31", base_url: base_url()})
  end

  # TODO: Remove this once we have a real store
  def test_store(email) do
    %{
      id: Uniq.UUID.uuid7(),
      email: email,
      name: "Test Store"
    }
  end

  # Delivers the email using the application mailer.
  @spec deliver(atom(), {String.t(), String.t()}, String.t(), map) ::
          {:ok, Swoosh.Email.t()} | {:error, term}
  defp deliver(template, recipient, subject, assigns) do
    assigns = Map.put(assigns, :recipient, recipient)

    {:ok, text_body} = apply_template(template, :txt, assigns)

    email =
      new()
      |> to(recipient)
      |> from({"Ahead", "notifications@buyahead.co"})
      |> subject(subject)
      |> text_body(text_body)
      |> maybe_apply_mjml_body(template, assigns)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  # Applies the template to the assigns.
  @spec apply_template(atom(), atom(), map) :: {:ok, String.t()} | {:error, :template_not_found}
  defp apply_template(template, suffix, assigns) do
    func = String.to_existing_atom("#{template}_#{suffix}")

    if function_exported?(Emails, func, 1) do
      {:ok, apply(Emails, func, [assigns])}
    else
      Logger.error("message=template-not-found template=#{template} suffix=#{suffix}")
      {:error, :template_not_found}
    end
  rescue
    e ->
      Logger.error("message=undefined-template error=#{inspect(e)}")
      {:error, :template_not_found}
  end

  @spec maybe_apply_mjml_body(Swoosh.Email.t(), atom(), map) :: Swoosh.Email.t()
  defp maybe_apply_mjml_body(email, template, assigns) do
    case apply_template(template, :mjml, assigns) do
      {:ok, mjml} ->
        {:ok, html} = Mjml.to_html(mjml)
        html_body(email, html)

      {:error, :template_not_found} ->
        email
    end
  end

  ##### Config #####

  @spec base_url :: String.t()
  defp base_url do
    Application.get_env(:antonia, __MODULE__)[:base_url]
  end
end

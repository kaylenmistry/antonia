defmodule Antonia.Mailer.Notifier do
  @moduledoc """
  Delivers emails to users.
  """

  use Gettext, backend: AntoniaWeb.Gettext

  import Swoosh.Email

  require Logger

  alias Antonia.Mailer
  alias Antonia.Mailer.Emails

  alias Antonia.Revenue.Report
  alias Antonia.Revenue.Store

  @doc "Delivers the monthly reminder email to a recipient store"
  @spec deliver_monthly_reminder(Store.t(), Report.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_monthly_reminder(store, report) do
    subject = gettext("Revenue report due")
    assigns = email_assigns(store, report)

    deliver(:monthly_reminder, store.email, subject, assigns)
  end

  @doc "Delivers the overdue reminder email to a recipient store"
  @spec deliver_overdue_reminder(Store.t(), Report.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_overdue_reminder(store, report) do
    subject = gettext("REMINDER: Report revenue due")
    assigns = email_assigns(store, report)

    deliver(:overdue_reminder, store.email, subject, assigns)
  end

  @doc "Delivers the submission receipt email to a recipient store"
  @spec deliver_submission_receipt(Store.t(), Report.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_submission_receipt(store, report) do
    subject = gettext("Thank you")
    assigns = email_assigns(store, report)

    deliver(:submission_receipt, store.email, subject, assigns)
  end

  @spec email_assigns(Store.t(), Report.t()) :: map()
  defp email_assigns(store, report) do
    %{
      store: store,
      period_start: report.period_start,
      period_end: report.period_end,
      base_url: base_url()
    }
  end

  # Delivers the email using the application mailer.
  @spec deliver(atom(), String.t(), String.t(), map()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
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

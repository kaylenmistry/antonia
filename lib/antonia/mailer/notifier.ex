defmodule Antonia.Mailer.Notifier do
  @moduledoc """
  Delivers emails to users.
  """

  use Gettext, backend: AntoniaWeb.Gettext

  import Swoosh.Email

  require Logger

  alias Antonia.Mailer
  alias Antonia.Mailer.Emails
  alias Antonia.Repo
  alias Antonia.Revenue.EmailLog
  alias Antonia.Revenue.Report
  alias Antonia.Revenue.Store

  @doc "Delivers the monthly reminder email to a recipient store"
  @spec deliver_monthly_reminder(Store.t(), Report.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_monthly_reminder(store, report) do
    Gettext.with_locale(AntoniaWeb.Gettext, "de", fn ->
      subject = "#{gettext("Revenue report due")} #{store.name}"
      assigns = email_assigns(store, report)

      deliver_with_logging(:monthly_reminder, store.email, subject, assigns, report)
    end)
  end

  @doc "Delivers the overdue reminder email to a recipient store"
  @spec deliver_overdue_reminder(Store.t(), Report.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_overdue_reminder(store, report) do
    Gettext.with_locale(AntoniaWeb.Gettext, "de", fn ->
      subject = "#{gettext("REMINDER: Revenue report due")} #{store.name}"
      assigns = email_assigns(store, report)

      deliver_with_logging(:overdue_reminder, store.email, subject, assigns, report)
    end)
  end

  @doc "Delivers the submission receipt email to a recipient store"
  @spec deliver_submission_receipt(Store.t(), Report.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_submission_receipt(store, report) do
    Gettext.with_locale(AntoniaWeb.Gettext, "de", fn ->
      subject = "#{gettext("Acknowledgement of receipt of revenue report")} #{store.name}"
      assigns = email_assigns(store, report)

      deliver_with_logging(:submission_receipt, store.email, subject, assigns, report)
    end)
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

  # Delivers the email with logging using a transaction
  @spec deliver_with_logging(String.t(), String.t(), String.t(), map(), Report.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  defp deliver_with_logging(email_type, recipient, subject, assigns, report) do
    case Repo.transaction(fn ->
           create_email_log_and_send(email_type, recipient, subject, assigns, report)
         end) do
      {:ok, result} -> result
      {:error, error} -> {:error, error}
    end
  end

  # Creates email log and sends the email
  @spec create_email_log_and_send(String.t(), String.t(), String.t(), map(), Report.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  defp create_email_log_and_send(email_type, recipient, subject, assigns, report) do
    email_log_attrs = %{
      report_id: report.id,
      email_type: email_type,
      recipient_email: recipient,
      subject: subject,
      status: :pending
    }

    case Repo.insert(EmailLog.changeset(%EmailLog{}, email_log_attrs)) do
      {:ok, email_log} ->
        send_and_log_email(email_type, recipient, subject, assigns, email_log)

      {:error, changeset} ->
        Repo.rollback(changeset)
    end
  end

  # Sends email and updates the log based on result
  @spec send_and_log_email(String.t(), String.t(), String.t(), map(), EmailLog.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  defp send_and_log_email(email_type, recipient, subject, assigns, email_log) do
    case deliver(email_type, recipient, subject, assigns) do
      {:ok, email} ->
        email_log
        |> EmailLog.mark_sent()
        |> Repo.update!()

        {:ok, email}

      {:error, error} ->
        email_log
        |> EmailLog.mark_failed(inspect(error))
        |> Repo.update!()

        {:error, error}
    end
  end

  # Delivers the email using the application mailer.
  @spec deliver(String.t(), String.t(), String.t(), map()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  defp deliver(template, recipient, subject, assigns) do
    assigns = Map.put(assigns, :recipient, recipient)

    {:ok, text_body} = apply_template(template, :txt, assigns)

    email =
      new()
      |> to(recipient)
      |> Swoosh.Email.from({"Realverwaltung GmbH", "notifications@buyahead.co"})
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

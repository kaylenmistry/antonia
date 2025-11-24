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
  alias Antonia.Services.S3

  @doc "Delivers the monthly reminder email to a recipient store"
  @spec deliver_monthly_reminder(Store.t(), Report.t(), integer() | nil) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_monthly_reminder(store, report, oban_job_id \\ nil) do
    Gettext.with_locale(AntoniaWeb.Gettext, "en", fn ->
      subject = gettext("Revenue report due")
      # Token will be generated in create_email_log_and_send
      deliver_with_logging(:monthly_reminder, store.email, subject, report, oban_job_id)
    end)
  end

  @doc "Delivers the overdue reminder email to a recipient store"
  @spec deliver_overdue_reminder(Store.t(), Report.t(), integer() | nil) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_overdue_reminder(store, report, oban_job_id \\ nil) do
    Gettext.with_locale(AntoniaWeb.Gettext, "en", fn ->
      subject = gettext("REMINDER: Report revenue due")
      # Token will be generated in create_email_log_and_send
      deliver_with_logging(:overdue_reminder, store.email, subject, report, oban_job_id)
    end)
  end

  @doc "Delivers the submission receipt email to a recipient store"
  @spec deliver_submission_receipt(Store.t(), Report.t(), integer() | nil) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_submission_receipt(store, report, oban_job_id \\ nil) do
    Gettext.with_locale(AntoniaWeb.Gettext, "en", fn ->
      subject = gettext("Thank you")
      # Token will be generated in create_email_log_and_send
      deliver_with_logging(:submission_receipt, store.email, subject, report, oban_job_id)
    end)
  end

  @spec email_assigns(Store.t(), Report.t(), String.t() | nil, Antonia.Revenue.Group.t()) :: map()
  defp email_assigns(store, report, submission_token, group) do
    submission_url =
      if submission_token do
        "#{base_url()}/submit/#{submission_token}"
      else
        nil
      end

    # Get logo URL - use group's custom logo or default
    logo_url =
      if group.email_logo_url do
        # If it's an S3 key, get presigned URL, otherwise use as-is
        case S3.presign_read(group.email_logo_url) do
          {:ok, url} -> url
          {:error, _} -> "https://rutter.at/themes/rutter/img/rutter-logo.png"
        end
      end

    # Get company name - use group's custom name or default to group name
    company_name = group.email_company_name || group.name || "Realverwaltung GmbH"

    # Use company name for email from field
    email_from = company_name

    %{
      store: store,
      period_start: report.period_start,
      period_end: report.period_end,
      base_url: base_url(),
      submission_url: submission_url,
      logo_url: logo_url,
      company_name: company_name,
      email_from: email_from
    }
  end

  # Delivers the email with logging using a transaction
  @spec deliver_with_logging(atom(), String.t(), String.t(), Report.t(), integer() | nil) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  defp deliver_with_logging(email_type, recipient, subject, report, oban_job_id) do
    case Repo.transaction(fn ->
           create_email_log_and_send(email_type, recipient, subject, report, oban_job_id)
         end) do
      {:ok, result} -> result
      {:error, error} -> {:error, error}
    end
  end

  # Creates email log and sends the email
  @spec create_email_log_and_send(atom(), String.t(), String.t(), Report.t(), integer() | nil) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  defp create_email_log_and_send(email_type, recipient, subject, report, oban_job_id) do
    # Get store and group for email assigns (ensure they're preloaded)
    report = Repo.preload(report, store: [building: :group])
    store = report.store
    group = store.building.group

    {submission_token, expires_at} = generate_submission_token_if_needed(email_type)

    email_log_attrs = %{
      report_id: report.id,
      email_type: email_type,
      recipient_email: recipient,
      subject: subject,
      status: :pending,
      oban_job_id: oban_job_id,
      submission_token: submission_token,
      expires_at: expires_at
    }

    case Repo.insert(EmailLog.changeset(%EmailLog{}, email_log_attrs)) do
      {:ok, email_log} ->
        assigns = email_assigns(store, report, submission_token, group)
        send_and_log_email(email_type, recipient, subject, assigns, email_log)

      {:error, changeset} ->
        Repo.rollback(changeset)
    end
  end

  # Generates submission token and expiry for reminder emails
  @spec generate_submission_token_if_needed(atom()) :: {String.t() | nil, DateTime.t() | nil}
  defp generate_submission_token_if_needed(email_type)
       when email_type in [:monthly_reminder, :overdue_reminder] do
    {EmailLog.generate_submission_token(), EmailLog.calculate_expires_at()}
  end

  defp generate_submission_token_if_needed(_), do: {nil, nil}

  # Sends email and updates the log based on result
  @spec send_and_log_email(atom(), String.t(), String.t(), map(), EmailLog.t()) ::
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
  @spec deliver(atom(), String.t(), String.t(), map()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  defp deliver(template, recipient, subject, assigns) do
    assigns = Map.put(assigns, :recipient, recipient)

    {:ok, text_body} = apply_template(template, :txt, assigns)

    from_name = assigns[:email_from] || "Revenue Report"

    email =
      new()
      |> to(recipient)
      |> Swoosh.Email.from({from_name, "notifications@revenue-report.com"})
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

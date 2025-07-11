defmodule Antonia.MailerWorker do
  use Oban.Worker, queue: :mailers

  alias Antonia.Mailer.Notifier

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"email" => email}}) do
    _ = Notifier.deliver_overdue_reminder(email)
    :ok
  end
end

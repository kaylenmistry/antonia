defmodule Antonia.MailerWorker do
  @moduledoc false
  use Oban.Worker, queue: :mailers

  # alias Antonia.Mailer.Notifier

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"email" => _email}}) do
    # _ = Notifier.deliver_overdue_reminder()
    :ok
  end
end

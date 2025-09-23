defmodule Antonia.Scheduler do
  @moduledoc """
  Quantum scheduler for periodic jobs in Antonia.

  Handles:
  - Monthly report creation
  - Initial email sending
  - Follow-up reminder checking
  """

  use Quantum, otp_app: :antonia
end

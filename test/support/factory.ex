defmodule Antonia.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Antonia.Repo

  alias Antonia.Revenue.EmailLog
  alias Antonia.Revenue.Report
  alias Antonia.Revenue.ShoppingCentre
  alias Antonia.Revenue.Store

  def shopping_centre_factory do
    %ShoppingCentre{
      name: sequence(:name, &"Test Shopping Centre #{&1}")
    }
  end

  def store_factory do
    %Store{
      name: sequence(:name, &"Test Store #{&1}"),
      email: sequence(:email, &"test#{&1}@example.com"),
      shopping_centre: build(:shopping_centre)
    }
  end

  def report_factory do
    %Report{
      store: build(:store),
      status: :pending,
      currency: "AUD",
      revenue: 1000.00,
      period_start: Date.new!(2025, 1, 1),
      period_end: Date.new!(2025, 1, 31),
      due_date: Date.new!(2025, 2, 7)
    }
  end

  def email_log_factory do
    %EmailLog{
      report: build(:report),
      email_type: :monthly_reminder,
      recipient_email: "test@example.com",
      subject: "Revenue report due",
      status: :pending
    }
  end
end

defmodule Antonia.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Antonia.Repo

  alias Antonia.Accounts.User
  alias Antonia.Revenue.Building
  alias Antonia.Revenue.EmailLog
  alias Antonia.Revenue.Group
  alias Antonia.Revenue.Report
  alias Antonia.Revenue.Store

  @spec user_factory :: User.t()
  def user_factory do
    %User{
      id: Uniq.UUID.uuid7(),
      uid: sequence(:uid, &"user-#{&1}"),
      provider: :kinde,
      first_name: "A",
      last_name: "Head",
      email: sequence(:email, &"user-#{&1}@mistry.co")
    }
  end

  def group_factory do
    %Group{
      name: sequence(:name, &"Test Group #{&1}")
    }
  end

  def building_factory do
    %Building{
      name: sequence(:name, &"Test Building #{&1}"),
      group: build(:group)
    }
  end

  def store_factory do
    %Store{
      name: sequence(:name, &"Test Store #{&1}"),
      email: sequence(:email, &"test#{&1}@example.com"),
      # Generate area between 25-300
      area: sequence(:area, &(&1 * 50 + 25)),
      building: build(:building)
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

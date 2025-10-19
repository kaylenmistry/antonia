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
      email: sequence(:email, &"user-#{&1}@revenue.com"),
      first_name: "Test",
      last_name: "User",
      location: "Test City",
      image: "https://example.com/avatar.jpg"
    }
  end

  @spec group_factory :: Group.t()
  def group_factory(attrs \\ %{}) do
    user = Map.get_lazy(attrs, :created_by_user, fn -> insert(:user) end)

    group = %Group{
      name: sequence(:name, &"Test Group #{&1}"),
      created_by_user_id: user.id
    }

    merge_attributes(group, attrs)
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
      revenue: sequence(:revenue, &(&1 * 1000.0 + 500.0)),
      period_start: sequence(:period_start, &Date.new!(2025, rem(&1, 12) + 1, 1)),
      period_end: sequence(:period_end, &Date.new!(2025, rem(&1, 12) + 1, 28)),
      due_date: sequence(:due_date, &Date.new!(2025, rem(&1, 12) + 1, 7))
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

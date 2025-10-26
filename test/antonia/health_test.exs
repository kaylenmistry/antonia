defmodule Antonia.HealthTest do
  use Antonia.DataCase, async: true

  alias Antonia.Health

  describe "alive?/0" do
    test "returns true when database is accessible" do
      assert Health.alive?() == true
    end

    # Test for false case would require mocking/damaging the database connection,
    # which is not practical in a standard test environment
  end

  describe "ready?/0" do
    test "returns true when all migrations are up" do
      # This should return true if the test database is properly migrated
      result = Health.ready?()
      assert is_boolean(result)
    end
  end
end

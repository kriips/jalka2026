defmodule Jalka2026.Accounts.AllowedUserTest do
  use Jalka2026.DataCase

  alias Jalka2026.Accounts.AllowedUser

  describe "changeset/2" do
    test "creates valid changeset with attributes" do
      changeset = AllowedUser.changeset(%AllowedUser{}, %{name: "Test User", competition_id: Jalka2026.Competitions.current_id()})
      assert changeset.valid?
    end

    test "default competition_id matches current competition" do
      user = %AllowedUser{}
      assert user.competition_id == Jalka2026.Competitions.current_id()
    end
  end
end

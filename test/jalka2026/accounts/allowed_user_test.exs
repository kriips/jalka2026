defmodule Jalka2026.Accounts.AllowedUserTest do
  use Jalka2026.DataCase

  alias Jalka2026.Accounts.AllowedUser

  describe "changeset/2" do
    test "creates valid changeset with attributes" do
      changeset = AllowedUser.changeset(%AllowedUser{}, %{name: "Test User", competition_id: "wc-2026"})
      assert changeset.valid?
    end

    test "default competition_id is wc-2026" do
      user = %AllowedUser{}
      assert user.competition_id == "wc-2026"
    end
  end
end

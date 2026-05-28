defmodule Jalka2026.CompetitionsTest do
  use Jalka2026.DataCase

  alias Jalka2026.Competitions
  alias Jalka2026.Football.Competition
  import Jalka2026.FootballFixtures

  describe "current_id/0" do
    test "returns the configured competition id" do
      result = Competitions.current_id()
      assert is_binary(result)
      assert result == "wc-2026"
    end
  end

  describe "current/0" do
    test "returns the current competition" do
      ensure_competition_exists()
      result = Competitions.current()
      assert %Competition{} = result
      assert result.id == Competitions.current_id()
    end
  end

  describe "current!/0" do
    test "returns the current competition when it exists" do
      ensure_competition_exists()
      result = Competitions.current!()
      assert %Competition{} = result
    end
  end

  describe "get/1" do
    test "returns competition by id" do
      comp = ensure_competition_exists()
      result = Competitions.get(comp.id)
      assert result.id == comp.id
    end

    test "returns nil for non-existent id" do
      result = Competitions.get("non-existent")
      assert result == nil
    end
  end

  describe "get!/1" do
    test "returns competition by id" do
      comp = ensure_competition_exists()
      result = Competitions.get!(comp.id)
      assert result.id == comp.id
    end
  end

  describe "list/0" do
    test "returns all competitions" do
      ensure_competition_exists()
      result = Competitions.list()
      assert is_list(result)
      assert result != []
    end
  end

  describe "list_active/0" do
    test "returns active competitions" do
      ensure_competition_exists()
      result = Competitions.list_active()
      assert is_list(result)
      assert Enum.all?(result, fn c -> c.is_active end)
    end
  end

  describe "id/1" do
    test "extracts id from Competition struct" do
      comp = ensure_competition_exists()
      assert Competitions.id(comp) == comp.id
    end

    test "returns string id as-is" do
      assert Competitions.id("wc-2026") == "wc-2026"
    end

    test "returns current_id for nil" do
      assert Competitions.id(nil) == Competitions.current_id()
    end
  end
end

defmodule Jalka2026.Football.CacheTest do
  use Jalka2026.DataCase

  alias Jalka2026.Football.Cache
  import Jalka2026.FootballFixtures

  describe "enabled?/0" do
    test "returns false in test environment" do
      refute Cache.enabled?()
    end
  end

  describe "get_teams/0" do
    test "returns teams from database (cache disabled in test)" do
      team = team_fixture(%{name: "Cache Test Team"})

      result = Cache.get_teams()

      assert is_list(result)
      team_ids = Enum.map(result, & &1.id)
      assert team.id in team_ids
    end
  end

  describe "get_team/1" do
    test "returns team by id from database" do
      team = team_fixture(%{name: "Cache Team By Id"})

      result = Cache.get_team(team.id)

      assert result.id == team.id
      assert result.name == "Cache Team By Id"
    end

    test "returns nil for non-existent id" do
      result = Cache.get_team(-1)
      assert result == nil
    end
  end

  describe "get_team_by_name/1" do
    test "returns teams by name from database" do
      team = team_fixture(%{name: "Cache Name Team"})

      result = Cache.get_team_by_name("Cache Name Team")

      assert is_list(result)
      assert result != []
      assert hd(result).id == team.id
    end

    test "returns empty list for non-existent name" do
      result = Cache.get_team_by_name("NonExistentTeamXYZ123")
      assert result == []
    end
  end

  describe "get_teams_by_group/0" do
    test "returns teams grouped by group letter" do
      team_a = team_fixture(%{name: "Group A Cache", group: "A"})
      team_b = team_fixture(%{name: "Group B Cache", group: "B"})

      result = Cache.get_teams_by_group()

      assert is_map(result)
      a_ids = Enum.map(result["A"] || [], fn {id, _name} -> id end)
      b_ids = Enum.map(result["B"] || [], fn {id, _name} -> id end)
      assert team_a.id in a_ids
      assert team_b.id in b_ids
    end
  end

  describe "get_current_competition/0" do
    test "returns the current competition from database" do
      ensure_competition_exists()

      result = Cache.get_current_competition()

      assert result != nil
      assert result.id == Jalka2026.Competitions.current_id()
    end
  end
end

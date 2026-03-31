defmodule Jalka2026.Football.GroupScenariosTest do
  use Jalka2026.DataCase

  alias Jalka2026.Football.GroupScenarios
  import Jalka2026.FootballFixtures

  describe "valid_groups/0" do
    test "returns all 12 group letters" do
      groups = GroupScenarios.valid_groups()
      assert length(groups) == 12
      assert "A" in groups
      assert "L" in groups
    end
  end

  describe "get_group_standings/1" do
    test "returns standings for a group with matches" do
      team1 = team_fixture(%{name: "GS Team A", group: "A"})
      team2 = team_fixture(%{name: "GS Team B", group: "A"})

      _finished = finished_match_fixture(%{
        home_team: team1,
        away_team: team2,
        home_score: 2,
        away_score: 1,
        group: "Alagrupp A"
      })

      standings = GroupScenarios.get_group_standings("A")
      assert is_list(standings)

      team1_standing = Enum.find(standings, fn s -> s.team.id == team1.id end)
      assert team1_standing != nil, "Expected team1 to appear in standings"
      assert team1_standing.won == 1
      assert team1_standing.points == 3
      assert team1_standing.goals_for == 2
      assert team1_standing.goals_against == 1
    end

    test "returns empty standings for group without matches" do
      standings = GroupScenarios.get_group_standings("L")
      assert is_list(standings)
    end
  end

  describe "get_remaining_matches/1" do
    test "returns unfinished matches for a group, including created fixture" do
      team1 = team_fixture(%{group: "B"})
      team2 = team_fixture(%{group: "B"})

      unfinished = match_fixture(%{
        home_team: team1,
        away_team: team2,
        group: "Alagrupp B",
        finished: false
      })

      remaining = GroupScenarios.get_remaining_matches("B")
      assert is_list(remaining)
      # The created fixture must be present in the list
      remaining_ids = Enum.map(remaining, & &1.id)
      assert unfinished.id in remaining_ids
    end

    test "does not return finished matches in remaining" do
      team1 = team_fixture(%{group: "I"})
      team2 = team_fixture(%{group: "I"})

      finished = finished_match_fixture(%{
        home_team: team1,
        away_team: team2,
        group: "Alagrupp I"
      })

      remaining = GroupScenarios.get_remaining_matches("I")
      remaining_ids = Enum.map(remaining, & &1.id)
      refute finished.id in remaining_ids, "Finished match should not appear in remaining matches"
    end
  end

  describe "get_finished_matches/1" do
    test "returns finished matches for a group, including created fixture" do
      team1 = team_fixture(%{group: "C"})
      team2 = team_fixture(%{group: "C"})

      finished = finished_match_fixture(%{
        home_team: team1,
        away_team: team2,
        group: "Alagrupp C"
      })

      finished_matches = GroupScenarios.get_finished_matches("C")
      assert is_list(finished_matches)
      finished_ids = Enum.map(finished_matches, & &1.id)
      assert finished.id in finished_ids
    end

    test "does not return unfinished matches as finished" do
      team1 = team_fixture(%{group: "J"})
      team2 = team_fixture(%{group: "J"})

      unfinished = match_fixture(%{
        home_team: team1,
        away_team: team2,
        group: "Alagrupp J",
        finished: false
      })

      finished = GroupScenarios.get_finished_matches("J")
      finished_ids = Enum.map(finished, & &1.id)
      refute unfinished.id in finished_ids, "Unfinished match should not appear in finished matches"
    end
  end

  describe "calculate_scenarios/1" do
    test "returns in_progress status when there are remaining matches" do
      # Group D already has unfinished matches in the seeded data
      result = GroupScenarios.calculate_scenarios("D")
      assert result.status == :in_progress
    end

    test "calculate_scenarios returns a valid status atom" do
      result = GroupScenarios.calculate_scenarios("A")
      assert result.status in [:completed, :in_progress]
      assert Map.has_key?(result, :status)
    end
  end

  describe "calculate_predicted_standings/1" do
    test "calculates standings from predictions" do
      team1 = team_fixture(%{group: "E"})
      team2 = team_fixture(%{group: "E"})
      match = match_fixture(%{home_team: team1, away_team: team2, group: "Alagrupp E"})

      predictions = [{match, {2, 1}}]
      standings = GroupScenarios.calculate_predicted_standings(predictions)

      assert is_list(standings)
      assert length(standings) == 2

      # First team (winner) should have 3 points
      assert hd(standings).points == 3
      assert hd(standings).won == 1
    end

    test "handles draws correctly" do
      team1 = team_fixture(%{group: "F"})
      team2 = team_fixture(%{group: "F"})
      match = match_fixture(%{home_team: team1, away_team: team2, group: "Alagrupp F"})

      predictions = [{match, {1, 1}}]
      standings = GroupScenarios.calculate_predicted_standings(predictions)

      # Both teams should have 1 point
      Enum.each(standings, fn s ->
        assert s.points == 1
        assert s.drawn == 1
      end)
    end

    test "skips predictions with dash values" do
      team1 = team_fixture(%{group: "G"})
      team2 = team_fixture(%{group: "G"})
      match = match_fixture(%{home_team: team1, away_team: team2, group: "Alagrupp G"})

      predictions = [{match, {"-", "-"}}]
      standings = GroupScenarios.calculate_predicted_standings(predictions)

      # All teams should have 0 points since predictions are not filled
      Enum.each(standings, fn s ->
        assert s.points == 0
        assert s.played == 0
      end)
    end
  end

  describe "get_predicted_qualifiers/1" do
    test "returns top 2 team IDs from predictions" do
      team1 = team_fixture(%{group: "H"})
      team2 = team_fixture(%{group: "H"})
      team3 = team_fixture(%{group: "H"})
      match1 = match_fixture(%{home_team: team1, away_team: team2, group: "Alagrupp H"})
      match2 = match_fixture(%{home_team: team1, away_team: team3, group: "Alagrupp H"})
      match3 = match_fixture(%{home_team: team2, away_team: team3, group: "Alagrupp H"})

      predictions = [
        {match1, {3, 0}},
        {match2, {2, 0}},
        {match3, {1, 0}}
      ]

      qualifiers = GroupScenarios.get_predicted_qualifiers(predictions)
      assert length(qualifiers) == 2
      # team1 won both, team2 won one - they should qualify
      assert team1.id in qualifiers
      assert team2.id in qualifiers
    end
  end
end

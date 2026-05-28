defmodule Jalka2026.Football.EnterResultMultiTest do
  use Jalka2026.DataCase

  alias Jalka2026.Football
  import Jalka2026.FootballFixtures
  import Jalka2026.AccountsFixtures

  describe "enter_match_result/3" do
    test "returns {:ok, results} with named steps on success" do
      match = match_fixture()

      assert {:ok, results} = Football.enter_match_result(match.id, 2, 1)

      assert Map.has_key?(results, :validate_match)
      assert Map.has_key?(results, :update_match)
      assert Map.has_key?(results, :recalc_leaderboard)
      assert Map.has_key?(results, :send_notifications)
    end

    test "updates match score, result, and finished flag" do
      match = match_fixture()

      {:ok, %{update_match: updated_match}} = Football.enter_match_result(match.id, 3, 0)

      assert updated_match.home_score == 3
      assert updated_match.away_score == 0
      assert updated_match.result == "home"
      assert updated_match.finished == true
    end

    test "returns {:error, :validate_match, ...} for non-existent match" do
      assert {:error, :validate_match, :match_not_found, %{}} =
               Football.enter_match_result(999_999_999, 1, 0)
    end

    test "correctly sets draw result" do
      match = match_fixture()

      {:ok, %{update_match: updated_match}} = Football.enter_match_result(match.id, 1, 1)

      assert updated_match.result == "draw"
    end

    test "correctly sets away result" do
      match = match_fixture()

      {:ok, %{update_match: updated_match}} = Football.enter_match_result(match.id, 0, 2)

      assert updated_match.result == "away"
    end

    test "recalculates leaderboard as part of the pipeline" do
      user = user_fixture()
      match = match_fixture()

      _prediction =
        group_prediction_fixture(%{user: user, match: match, home_score: 2, away_score: 1})

      {:ok, %{recalc_leaderboard: leaderboard}} = Football.enter_match_result(match.id, 2, 1)

      assert is_list(leaderboard)
    end
  end

  describe "enter_playoff_result/2" do
    test "returns {:ok, results} with named steps on success" do
      team = team_fixture(%{name: "Multi Test Team #{System.unique_integer([:positive])}"})

      assert {:ok, results} = Football.enter_playoff_result(team.name, 32)

      assert Map.has_key?(results, :resolve_team)
      assert Map.has_key?(results, :toggle_playoff_result)
      assert Map.has_key?(results, :recalc_leaderboard)
      assert Map.has_key?(results, :send_notifications)
    end

    test "inserts playoff result when none exists" do
      team = team_fixture(%{name: "Insert Test Team #{System.unique_integer([:positive])}"})

      {:ok, %{toggle_playoff_result: result}} = Football.enter_playoff_result(team.name, 16)

      assert result.team_id == team.id
      assert result.phase == 16
    end

    test "deletes playoff result when one already exists (toggle)" do
      team = team_fixture(%{name: "Toggle Test Team #{System.unique_integer([:positive])}"})
      _existing = playoff_result_fixture(%{team: team, phase: 8})

      {:ok, %{toggle_playoff_result: deleted}} = Football.enter_playoff_result(team.name, 8)

      assert deleted.team_id == team.id
      # After toggle-delete, the record should not exist
      assert Football.get_playoff_result_by_phase_team(8, team.id) == nil
    end

    test "returns {:error, :resolve_team, ...} for unknown team" do
      assert {:error, :resolve_team, :team_not_found, %{}} =
               Football.enter_playoff_result("Nonexistent Team XYZ 999", 32)
    end

    test "accepts string phase parameter" do
      team = team_fixture(%{name: "String Phase Team #{System.unique_integer([:positive])}"})

      assert {:ok, _results} = Football.enter_playoff_result(team.name, "16")
    end
  end
end

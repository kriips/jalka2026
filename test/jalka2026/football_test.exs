defmodule Jalka2026.FootballTest do
  use Jalka2026.DataCase

  alias Jalka2026.Football
  import Jalka2026.FootballFixtures
  import Jalka2026.AccountsFixtures

  describe "get_matches_by_group/1" do
    test "returns matches for a specific group" do
      match = match_fixture(%{group: "Alagrupp A"})
      _other_match = match_fixture(%{group: "Alagrupp B"})

      result = Football.get_matches_by_group("Alagrupp A")

      assert result != []
      match_ids = Enum.map(result, & &1.id)
      assert match.id in match_ids
    end

    test "returns empty list when no matches in group" do
      assert Football.get_matches_by_group("Alagrupp Z") == []
    end
  end

  describe "get_finished_matches/0" do
    test "returns only finished matches" do
      finished = finished_match_fixture()
      _unfinished = match_fixture(%{finished: false})

      result = Football.get_finished_matches()

      assert length(result) == 1
      assert hd(result).id == finished.id
    end

    test "returns empty list when no finished matches" do
      _match = match_fixture(%{finished: false})
      assert Football.get_finished_matches() == []
    end
  end

  describe "get_matches/0" do
    test "returns all matches with preloaded teams" do
      match = match_fixture()

      result = Football.get_matches()

      assert result != []
      match_result = Enum.find(result, &(&1.id == match.id))
      assert match_result != nil
      assert match_result.home_team != nil
      assert match_result.away_team != nil
    end
  end

  describe "get_match/1" do
    test "returns a match with preloaded teams" do
      match = match_fixture()

      result = Football.get_match(match.id)

      assert result.id == match.id
      assert result.home_team != nil
      assert result.away_team != nil
    end

    test "returns nil for non-existent match" do
      assert Football.get_match(-1) == nil
    end
  end

  describe "get_prediction_by_user_match/2" do
    test "returns prediction for user and match combination" do
      user = user_fixture()
      match = match_fixture()
      prediction = group_prediction_fixture(%{user: user, match: match})

      result = Football.get_prediction_by_user_match(user.id, match.id)

      assert result.id == prediction.id
    end

    test "returns nil when no prediction exists" do
      user = user_fixture()
      match = match_fixture()

      assert Football.get_prediction_by_user_match(user.id, match.id) == nil
    end
  end

  describe "get_predictions_by_match/1" do
    test "returns all predictions for a match with preloaded user" do
      match = match_fixture()
      prediction = group_prediction_fixture(%{match: match})

      result = Football.get_predictions_by_match(match.id)

      assert length(result) == 1
      assert hd(result).id == prediction.id
      assert hd(result).user != nil
    end

    test "returns empty list for match with no predictions" do
      match = match_fixture()
      assert Football.get_predictions_by_match(match.id) == []
    end
  end

  describe "get_predictions_by_user/1" do
    test "returns all predictions for a user with preloaded match and teams" do
      user = user_fixture()
      prediction = group_prediction_fixture(%{user: user})

      result = Football.get_predictions_by_user(user.id)

      assert length(result) == 1
      assert hd(result).id == prediction.id
      assert hd(result).match != nil
      assert hd(result).match.home_team != nil
    end

    test "returns empty list for user with no predictions" do
      user = user_fixture()
      assert Football.get_predictions_by_user(user.id) == []
    end
  end

  describe "get_team_by_name/1" do
    test "returns teams matching the name" do
      team = team_fixture(%{name: "Finland"})

      result = Football.get_team_by_name("Finland")

      assert length(result) == 1
      assert hd(result).id == team.id
    end

    test "returns empty list for non-existent team" do
      assert Football.get_team_by_name("NonExistent") == []
    end
  end

  describe "get_teams/0" do
    test "returns all teams" do
      team1 = team_fixture()
      team2 = team_fixture()

      result = Football.get_teams()

      assert length(result) >= 2
      team_ids = Enum.map(result, & &1.id)
      assert team1.id in team_ids
      assert team2.id in team_ids
    end
  end

  describe "change_score/1" do
    test "creates a new prediction if none exists" do
      user = user_fixture()
      match = match_fixture()

      result =
        Football.change_score(%{
          user_id: user.id,
          match_id: match.id,
          home_score: 2,
          away_score: 1
        })

      assert result.home_score == 2
      assert result.away_score == 1
      assert result.user_id == user.id
      assert result.match_id == match.id
    end

    test "updates existing prediction" do
      user = user_fixture()
      match = match_fixture()

      _prediction =
        group_prediction_fixture(%{user: user, match: match, home_score: 1, away_score: 0})

      result =
        Football.change_score(%{
          user_id: user.id,
          match_id: match.id,
          home_score: 3,
          away_score: 2
        })

      assert result.home_score == 3
      assert result.away_score == 2
    end
  end

  describe "update_match_score/3" do
    test "updates match score and marks as finished" do
      match = match_fixture()

      Football.update_match_score(match.id, 2, 1)

      updated = Football.get_match(match.id)
      assert updated.home_score == 2
      assert updated.away_score == 1
      assert updated.finished == true
      assert updated.result == "home"
    end

    test "sets correct result for home win" do
      match = match_fixture()
      Football.update_match_score(match.id, 3, 0)
      updated = Football.get_match(match.id)
      assert updated.result == "home"
    end

    test "sets correct result for away win" do
      match = match_fixture()
      Football.update_match_score(match.id, 0, 2)
      updated = Football.get_match(match.id)
      assert updated.result == "away"
    end

    test "sets correct result for draw" do
      match = match_fixture()
      Football.update_match_score(match.id, 1, 1)
      updated = Football.get_match(match.id)
      assert updated.result == "draw"
    end
  end

  describe "playoff predictions" do
    test "get_playoff_predictions/0 returns all playoff predictions" do
      prediction = playoff_prediction_fixture()

      result = Football.get_playoff_predictions()

      assert result != []
      prediction_ids = Enum.map(result, & &1.id)
      assert prediction.id in prediction_ids
    end

    test "get_playoff_predictions_by_user/1 returns predictions for user" do
      user = user_fixture()
      prediction = playoff_prediction_fixture(%{user: user})

      result = Football.get_playoff_predictions_by_user(user.id)

      assert length(result) == 1
      assert hd(result).id == prediction.id
      assert hd(result).team != nil
    end

    test "get_playoff_prediction_by_user_phase_team/3 returns specific prediction" do
      user = user_fixture()
      team = team_fixture()
      prediction = playoff_prediction_fixture(%{user: user, team: team, phase: 16})

      result = Football.get_playoff_prediction_by_user_phase_team(user.id, 16, team.id)

      assert result.id == prediction.id
    end

    test "add_playoff_prediction/1 creates new prediction" do
      user = user_fixture()
      team = team_fixture()

      result =
        Football.add_playoff_prediction(%{
          user_id: user.id,
          team_id: team.id,
          phase: 8
        })

      assert result.user_id == user.id
      assert result.team_id == team.id
      assert result.phase == 8
    end

    test "add_playoff_prediction/1 updates existing prediction" do
      user = user_fixture()
      team = team_fixture()
      _prediction = playoff_prediction_fixture(%{user: user, team: team, phase: 16})

      # Adding the same prediction again should update, not create duplicate
      result =
        Football.add_playoff_prediction(%{
          user_id: user.id,
          team_id: team.id,
          phase: 16
        })

      predictions = Football.get_playoff_predictions_by_user(user.id)
      assert length(predictions) == 1
      assert result.phase == 16
    end

    test "remove_playoff_prediction/1 deletes prediction" do
      user = user_fixture()
      team = team_fixture()
      _prediction = playoff_prediction_fixture(%{user: user, team: team, phase: 16})

      Football.remove_playoff_prediction(%{
        user_id: user.id,
        team_id: team.id,
        phase: 16
      })

      result = Football.get_playoff_predictions_by_user(user.id)
      assert Enum.empty?(result)
    end
  end

  describe "playoff results" do
    test "get_playoff_results/0 returns all playoff results" do
      result_fixture = playoff_result_fixture()

      results = Football.get_playoff_results()

      assert results != []
      result_ids = Enum.map(results, & &1.id)
      assert result_fixture.id in result_ids
    end

    test "get_playoff_result_by_phase_team/2 returns specific result" do
      team = team_fixture()
      result_fixture = playoff_result_fixture(%{team: team, phase: 16})

      result = Football.get_playoff_result_by_phase_team(16, team.id)

      assert result.id == result_fixture.id
    end

    test "update_playoff_result/2 creates new result if none exists" do
      team = team_fixture()

      Football.update_playoff_result(8, team.id)

      result = Football.get_playoff_result_by_phase_team(8, team.id)
      assert result != nil
      assert result.team_id == team.id
      assert result.phase == 8
    end

    test "update_playoff_result/2 deletes existing result (toggle behavior)" do
      team = team_fixture()
      _result_fixture = playoff_result_fixture(%{team: team, phase: 16})

      Football.update_playoff_result(16, team.id)

      result = Football.get_playoff_result_by_phase_team(16, team.id)
      assert result == nil
    end
  end
end

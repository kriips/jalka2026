defmodule Jalka2026Web.Resolvers.FootballResolverTest do
  use Jalka2026.DataCase

  alias Jalka2026Web.Resolvers.FootballResolver
  import Jalka2026.FootballFixtures
  import Jalka2026.AccountsFixtures

  describe "calculate_result/2" do
    test "returns 'home' when home score is higher" do
      assert FootballResolver.calculate_result(3, 1) == "home"
      assert FootballResolver.calculate_result(2, 0) == "home"
      assert FootballResolver.calculate_result(5, 4) == "home"
    end

    test "returns 'away' when away score is higher" do
      assert FootballResolver.calculate_result(0, 1) == "away"
      assert FootballResolver.calculate_result(2, 3) == "away"
      assert FootballResolver.calculate_result(1, 5) == "away"
    end

    test "returns 'draw' when scores are equal" do
      assert FootballResolver.calculate_result(0, 0) == "draw"
      assert FootballResolver.calculate_result(1, 1) == "draw"
      assert FootballResolver.calculate_result(3, 3) == "draw"
    end
  end

  describe "list_matches_by_group/1" do
    test "returns matches for given group letter" do
      match = match_fixture(%{group: "Alagrupp B"})

      result = FootballResolver.list_matches_by_group("B")

      assert result != []
      match_ids = Enum.map(result, & &1.id)
      assert match.id in match_ids
    end
  end

  describe "list_matches/0" do
    test "returns all matches" do
      match1 = match_fixture()
      match2 = match_fixture()

      result = FootballResolver.list_matches()

      assert length(result) >= 2
      match_ids = Enum.map(result, & &1.id)
      assert match1.id in match_ids
      assert match2.id in match_ids
    end
  end

  describe "list_finished_matches/0" do
    test "returns only finished matches" do
      finished = finished_match_fixture()
      _unfinished = match_fixture()

      result = FootballResolver.list_finished_matches()

      assert length(result) == 1
      assert hd(result).id == finished.id
    end
  end

  describe "list_match/1" do
    test "returns match by id" do
      match = match_fixture()

      result = FootballResolver.list_match(match.id)

      assert result.id == match.id
    end
  end

  describe "get_prediction/1" do
    test "returns prediction for user and match" do
      user = user_fixture()
      match = match_fixture()
      prediction = group_prediction_fixture(%{user: user, match: match})

      result = FootballResolver.get_prediction(%{match_id: match.id, user_id: user.id})

      assert result.id == prediction.id
    end

    test "returns nil when no prediction exists" do
      user = user_fixture()
      match = match_fixture()

      result = FootballResolver.get_prediction(%{match_id: match.id, user_id: user.id})

      assert result == nil
    end
  end

  describe "change_prediction_score/1" do
    test "creates or updates prediction with calculated result" do
      user = user_fixture()
      match = match_fixture()

      result =
        FootballResolver.change_prediction_score(%{
          match_id: match.id,
          user_id: user.id,
          score: {2, 1}
        })

      assert result.home_score == 2
      assert result.away_score == 1
      assert result.result == "home"
    end

    test "correctly sets draw result" do
      user = user_fixture()
      match = match_fixture()

      result =
        FootballResolver.change_prediction_score(%{
          match_id: match.id,
          user_id: user.id,
          score: {1, 1}
        })

      assert result.result == "draw"
    end
  end

  describe "get_predictions_by_user/1" do
    test "returns predictions sorted by match date" do
      user = user_fixture()

      home_team1 = team_fixture()
      away_team1 = team_fixture()
      home_team2 = team_fixture()
      away_team2 = team_fixture()

      match1 =
        match_fixture(%{
          home_team: home_team1,
          away_team: away_team1,
          date: ~N[2026-06-15 18:00:00]
        })

      match2 =
        match_fixture(%{
          home_team: home_team2,
          away_team: away_team2,
          date: ~N[2026-06-10 18:00:00]
        })

      _prediction1 = group_prediction_fixture(%{user: user, match: match1})
      _prediction2 = group_prediction_fixture(%{user: user, match: match2})

      result = FootballResolver.get_predictions_by_user(user.id)

      assert length(result) == 2
      # Should be sorted by date, earlier first
      assert hd(result).match_id == match2.id
    end
  end

  describe "filled_predictions/1" do
    test "returns count of predictions per group" do
      user = user_fixture()
      match = match_fixture(%{group: "Alagrupp C"})
      _prediction = group_prediction_fixture(%{user: user, match: match})

      result = FootballResolver.filled_predictions(user.id)

      assert result["Alagrupp C"] == 1
      assert result["Alagrupp A"] == 0
    end
  end

  describe "get_playoff_predictions/1" do
    test "returns playoff predictions grouped by phase" do
      user = user_fixture()
      team = team_fixture()
      _prediction = playoff_prediction_fixture(%{user: user, team: team, phase: 16})

      result = FootballResolver.get_playoff_predictions(user.id)

      assert team.id in result[16]
      assert result[8] == []
    end
  end

  describe "get_teams_by_group/0" do
    test "returns teams grouped by their group letter" do
      team_a = team_fixture(%{name: "Team A Test", group: "A"})
      team_b = team_fixture(%{name: "Team B Test", group: "B"})

      result = FootballResolver.get_teams_by_group()

      assert {team_a.id, team_a.name} in result["A"]
      assert {team_b.id, team_b.name} in result["B"]
    end
  end

  describe "add_correctness/1" do
    test "adds correctness flags to predictions" do
      home_team = team_fixture()
      away_team = team_fixture()

      finished_match =
        finished_match_fixture(%{
          home_team: home_team,
          away_team: away_team,
          home_score: 2,
          away_score: 1
        })

      user = user_fixture()

      # Create a prediction with correct result but wrong score
      correct_result_prediction =
        group_prediction_fixture(%{
          user: user,
          match: finished_match,
          home_score: 3,
          away_score: 0
        })

      result = FootballResolver.add_correctness([correct_result_prediction])

      [{prediction, correct_result, correct_score}] = result
      assert prediction.id == correct_result_prediction.id
      assert correct_result == true
      assert correct_score == false
    end

    test "marks exact score predictions as correct" do
      home_team = team_fixture()
      away_team = team_fixture()

      finished_match =
        finished_match_fixture(%{
          home_team: home_team,
          away_team: away_team,
          home_score: 2,
          away_score: 1
        })

      user = user_fixture()

      # Create a prediction with exact score match
      exact_prediction =
        group_prediction_fixture(%{
          user: user,
          match: finished_match,
          home_score: 2,
          away_score: 1
        })

      result = FootballResolver.add_correctness([exact_prediction])

      [{_prediction, correct_result, correct_score}] = result
      assert correct_result == true
      assert correct_score == true
    end

    test "marks wrong result predictions as incorrect" do
      home_team = team_fixture()
      away_team = team_fixture()

      finished_match =
        finished_match_fixture(%{
          home_team: home_team,
          away_team: away_team,
          home_score: 2,
          away_score: 1
        })

      user = user_fixture()

      # Create a prediction with wrong result (away win instead of home win)
      wrong_prediction =
        group_prediction_fixture(%{
          user: user,
          match: finished_match,
          home_score: 0,
          away_score: 2
        })

      result = FootballResolver.add_correctness([wrong_prediction])

      [{_prediction, correct_result, correct_score}] = result
      assert correct_result == false
      assert correct_score == false
    end

    test "handles unfinished matches" do
      match = match_fixture(%{finished: false})
      user = user_fixture()
      prediction = group_prediction_fixture(%{user: user, match: match})

      result = FootballResolver.add_correctness([prediction])
      [{_pred, correct_result, _correct_score}] = result
      assert correct_result == false
    end
  end

  describe "get_crowd_confidence/1" do
    test "returns zero percentages for match with no predictions" do
      match = match_fixture()
      result = FootballResolver.get_crowd_confidence(match.id)

      assert result.home == 0.0
      assert result.draw == 0.0
      assert result.away == 0.0
      assert result.total == 0
      assert result.counts == %{home: 0, draw: 0, away: 0}
    end

    test "calculates correct percentages" do
      match = match_fixture()
      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()

      # 2 home, 1 away
      group_prediction_fixture(%{user: user1, match: match, home_score: 2, away_score: 1})
      group_prediction_fixture(%{user: user2, match: match, home_score: 3, away_score: 0})
      group_prediction_fixture(%{user: user3, match: match, home_score: 0, away_score: 1})

      result = FootballResolver.get_crowd_confidence(match.id)
      assert result.total == 3
      assert_in_delta result.home, 66.7, 0.1
      assert_in_delta result.away, 33.3, 0.1
      assert result.draw == 0.0
      assert result.counts.home == 2
      assert result.counts.away == 1
    end
  end

  describe "get_predictions_by_match_result/1" do
    test "groups predictions by result" do
      match = match_fixture()
      user1 = user_fixture()
      user2 = user_fixture()

      group_prediction_fixture(%{user: user1, match: match, home_score: 2, away_score: 1})
      group_prediction_fixture(%{user: user2, match: match, home_score: 0, away_score: 1})

      result = FootballResolver.get_predictions_by_match_result(match.id)
      assert is_map(result)
      assert Map.has_key?(result, "home")
      assert Map.has_key?(result, "away")
    end
  end

  describe "compare_predictions/2" do
    test "returns comparison structure with empty predictions" do
      user1 = user_fixture()
      user2 = user_fixture()

      result = FootballResolver.compare_predictions(user1.id, user2.id)

      assert Map.has_key?(result, :group_comparisons)
      assert Map.has_key?(result, :playoff_comparisons)
      assert Map.has_key?(result, :summary)
    end

    test "summary contains correct keys" do
      user1 = user_fixture()
      user2 = user_fixture()

      result = FootballResolver.compare_predictions(user1.id, user2.id)
      summary = result.summary

      assert Map.has_key?(summary, :user1_group_points)
      assert Map.has_key?(summary, :user2_group_points)
      assert Map.has_key?(summary, :user1_total_points)
      assert Map.has_key?(summary, :user2_total_points)
      assert Map.has_key?(summary, :finished_matches_count)
      assert Map.has_key?(summary, :total_matches_count)
    end
  end

  describe "list_playoff_results/0" do
    test "returns all playoff results" do
      _result = playoff_result_fixture()
      results = FootballResolver.list_playoff_results()
      assert is_list(results)
      assert results != []
    end
  end

  describe "get_playoff_predictions_with_team_names/1" do
    test "returns playoff predictions with team names" do
      user = user_fixture()
      team = team_fixture(%{name: "Test Team FR"})
      _prediction = playoff_prediction_fixture(%{user: user, team: team, phase: 16})

      result = FootballResolver.get_playoff_predictions_with_team_names(user.id)

      assert is_map(result)
      assert team.name in result[16]
      assert result[8] == []
    end
  end

  describe "get_predicted_qualifiers/1" do
    test "returns predicted qualifiers for user" do
      user = user_fixture()
      result = FootballResolver.get_predicted_qualifiers(user.id)
      # Returns a list of group-qualified teams map
      assert is_list(result) or is_map(result)
    end
  end

  describe "compare_predictions/2 with predictions" do
    test "compares group predictions correctly" do
      user1 = user_fixture()
      user2 = user_fixture()

      match = finished_match_fixture(%{home_score: 2, away_score: 1})

      # User1 predicts exact score (2 pts), User2 predicts wrong result (0 pts)
      group_prediction_fixture(%{user: user1, match: match, home_score: 2, away_score: 1})
      group_prediction_fixture(%{user: user2, match: match, home_score: 0, away_score: 2})

      result = FootballResolver.compare_predictions(user1.id, user2.id)

      assert result.summary.user1_group_points == 2
      assert result.summary.user2_group_points == 0
      assert result.summary.finished_matches_count == 1
    end

    test "playoff comparison shows common and unique teams" do
      user1 = user_fixture()
      user2 = user_fixture()
      team_common = team_fixture(%{name: "Common Team"})
      team_user1 = team_fixture(%{name: "User1 Team"})
      team_user2 = team_fixture(%{name: "User2 Team"})

      # Both predict common team
      playoff_prediction_fixture(%{user: user1, team: team_common, phase: 16})
      playoff_prediction_fixture(%{user: user2, team: team_common, phase: 16})
      # User1 only
      playoff_prediction_fixture(%{user: user1, team: team_user1, phase: 16})
      # User2 only
      playoff_prediction_fixture(%{user: user2, team: team_user2, phase: 16})

      result = FootballResolver.compare_predictions(user1.id, user2.id)

      phase16 = Enum.find(result.playoff_comparisons, fn c -> c.phase == 16 end)
      assert team_common.name in phase16.common_teams
      assert team_user1.name in phase16.only_user1
      assert team_user2.name in phase16.only_user2
    end
  end

  describe "add_playoff_correctness/1" do
    test "marks teams that reached phase as correct" do
      team = team_fixture(%{name: "Correct Team"})
      _result = playoff_result_fixture(%{team: team, phase: 16})

      input = %{16 => ["Correct Team"], 8 => []}
      result = FootballResolver.add_playoff_correctness(input)

      assert hd(result[16]) == %{name: "Correct Team", correct: true}
      assert result[8] == []
    end

    test "marks a translated team name as correct when it reached the phase" do
      # Teams are stored under their English name but display lists carry the Estonian translation;
      # correctness must still resolve via the translated name.
      team = team_fixture(%{name: "Germany"})
      _result = playoff_result_fixture(%{team: team, phase: 16})

      input = %{16 => ["Saksamaa"], 8 => []}
      result = FootballResolver.add_playoff_correctness(input)

      assert hd(result[16]) == %{name: "Saksamaa", correct: true}
    end

    test "does not mark teams that did not reach the phase" do
      input = %{16 => ["Saksamaa"], 8 => []}
      result = FootballResolver.add_playoff_correctness(input)

      assert hd(result[16]) == %{name: "Saksamaa", correct: false}
    end
  end

  describe "get_playoff_predictions/0" do
    test "returns aggregated playoff predictions" do
      user = user_fixture()
      team = team_fixture(%{name: "Playoff Team"})
      _prediction = playoff_prediction_fixture(%{user: user, team: team, phase: 32})

      result = FootballResolver.get_playoff_predictions()

      assert is_list(result)
      # Result should be sorted by phase descending (32 first)
      assert hd(result) |> elem(0) == 32
    end
  end

  describe "update_match/1" do
    test "updates match score and marks as finished" do
      match = match_fixture()

      result =
        FootballResolver.update_match(%{
          "game_id" => to_string(match.id),
          "home_score" => "3",
          "away_score" => "1"
        })

      assert {:ok, %{update_match: updated_match}} = result
      assert updated_match.home_score == 3
      assert updated_match.away_score == 1
      assert updated_match.finished == true
    end
  end

  describe "update_playoff_result/1" do
    test "enters a playoff result for a team" do
      team = team_fixture(%{name: "Playoff Winner Team"})

      result =
        FootballResolver.update_playoff_result(%{
          "team_name" => team.name,
          "phase" => 32
        })

      assert {:ok, %{toggle_playoff_result: _}} = result
    end
  end

  describe "get_prediction_analytics/1" do
    test "returns analytics structure with no predictions" do
      user = user_fixture()

      result = FootballResolver.get_prediction_analytics(user.id)

      assert %{
               group_stats: group_stats,
               playoff_stats: playoff_stats,
               trend_data: trend_data,
               overall_stats: overall_stats
             } = result

      assert group_stats.total_predictions == 0
      assert group_stats.total_finished == 0
      assert group_stats.correct_results == 0
      assert group_stats.result_accuracy == 0.0
      assert group_stats.by_group == %{}
      assert group_stats.best_group == nil
      assert group_stats.worst_group == nil

      assert playoff_stats.total_predictions == 0
      assert playoff_stats.total_correct == 0
      assert playoff_stats.overall_accuracy == 0.0

      assert trend_data.cumulative_accuracy == []
      assert trend_data.recent_form == []
      assert trend_data.streak_data.current == 0

      # Regression: the Trends tab always renders streak_data.longest_correct,
      # so the empty-data fallback must expose the same keys as the populated
      # case (previously returned %{current: 0, longest: 0, type: nil}, which
      # crashed the analytics page with a KeyError on longest_correct).
      assert trend_data.streak_data.longest_correct == 0
      assert trend_data.streak_data.longest_incorrect == 0
      assert trend_data.streak_data.type == nil

      assert overall_stats.total_points == 0
    end

    test "returns correct group stats with finished matches" do
      user = user_fixture()

      # Create matches in different groups
      match1 = finished_match_fixture(%{home_score: 2, away_score: 1, group: "Alagrupp A"})
      match2 = finished_match_fixture(%{home_score: 0, away_score: 0, group: "Alagrupp A"})
      match3 = finished_match_fixture(%{home_score: 1, away_score: 3, group: "Alagrupp B"})

      # Correct result prediction
      group_prediction_fixture(%{user: user, match: match1, home_score: 3, away_score: 0})
      # Wrong prediction
      group_prediction_fixture(%{user: user, match: match2, home_score: 1, away_score: 0})
      # Exact score prediction
      group_prediction_fixture(%{user: user, match: match3, home_score: 1, away_score: 3})

      result = FootballResolver.get_prediction_analytics(user.id)

      assert result.group_stats.total_finished == 3
      # match1 correct result, match3 correct result
      assert result.group_stats.correct_results == 2
      # match3 exact score
      assert result.group_stats.correct_scores == 1
      # 2 correct results + 1 exact score = 3
      assert result.group_stats.points_earned == 3
      assert result.group_stats.max_possible_points == 6

      assert result.overall_stats.group_points == 3
    end

    test "returns correct trend data with predictions" do
      user = user_fixture()

      match1 =
        finished_match_fixture(%{
          home_score: 2,
          away_score: 1,
          date: ~N[2026-06-10 18:00:00]
        })

      match2 =
        finished_match_fixture(%{
          home_score: 0,
          away_score: 0,
          date: ~N[2026-06-11 18:00:00]
        })

      # Correct result
      group_prediction_fixture(%{user: user, match: match1, home_score: 3, away_score: 0})
      # Wrong result
      group_prediction_fixture(%{user: user, match: match2, home_score: 1, away_score: 0})

      result = FootballResolver.get_prediction_analytics(user.id)

      assert length(result.trend_data.cumulative_accuracy) == 2
      assert result.trend_data.streak_data.current == 1
      assert result.trend_data.streak_data.type == :incorrect
    end

    test "calculates playoff stats correctly" do
      user = user_fixture()
      team = team_fixture(%{name: "Analytics Team"})
      _prediction = playoff_prediction_fixture(%{user: user, team: team, phase: 16})

      result = FootballResolver.get_prediction_analytics(user.id)

      assert result.playoff_stats.total_predictions >= 1
      assert is_map(result.playoff_stats.by_phase)
    end

    test "identifies best and worst groups with enough data" do
      user = user_fixture()

      # Create 3 matches per group to qualify for best/worst
      group_a_matches =
        for _ <- 1..3 do
          finished_match_fixture(%{home_score: 2, away_score: 1, group: "Alagrupp C"})
        end

      group_b_matches =
        for _ <- 1..3 do
          finished_match_fixture(%{home_score: 1, away_score: 0, group: "Alagrupp D"})
        end

      # Group C: all correct results
      for m <- group_a_matches do
        group_prediction_fixture(%{user: user, match: m, home_score: 3, away_score: 0})
      end

      # Group D: all wrong results
      for m <- group_b_matches do
        group_prediction_fixture(%{user: user, match: m, home_score: 0, away_score: 2})
      end

      result = FootballResolver.get_prediction_analytics(user.id)

      assert result.group_stats.best_group == "Alagrupp C"
      assert result.group_stats.worst_group == "Alagrupp D"
    end
  end
end

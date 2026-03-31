defmodule Jalka2026.FootballContextExtendedTest do
  use Jalka2026.DataCase

  alias Jalka2026.Football
  import Jalka2026.FootballFixtures
  import Jalka2026.AccountsFixtures

  describe "competition_id/0" do
    test "returns the default competition id" do
      assert Football.competition_id() == "wc-2026"
    end
  end

  describe "fifa_to_iso_code/1" do
    test "converts known FIFA codes to ISO codes" do
      assert Football.fifa_to_iso_code("GER") == "DEU"
      assert Football.fifa_to_iso_code("NED") == "NLD"
      assert Football.fifa_to_iso_code("POR") == "PRT"
      assert Football.fifa_to_iso_code("SUI") == "CHE"
      assert Football.fifa_to_iso_code("CRO") == "HRV"
      assert Football.fifa_to_iso_code("KSA") == "SAU"
      assert Football.fifa_to_iso_code("RSA") == "ZAF"
      assert Football.fifa_to_iso_code("URU") == "URY"
    end

    test "returns original code if no mapping exists" do
      assert Football.fifa_to_iso_code("BRA") == "BRA"
      assert Football.fifa_to_iso_code("FRA") == "FRA"
      assert Football.fifa_to_iso_code("ARG") == "ARG"
    end
  end

  describe "stage_display_name/1" do
    test "returns Estonian display names for known stages" do
      assert Football.stage_display_name("group stage") == "Alagrupifaas"
      assert Football.stage_display_name("Group Stage") == "Alagrupifaas"
      assert Football.stage_display_name("round of 16") == "16. finaal"
      assert Football.stage_display_name("quarter-finals") == "Veerandfinaal"
      assert Football.stage_display_name("semi-finals") == "Poolfinaal"
      assert Football.stage_display_name("third-place match") == "3. koha mäng"
      assert Football.stage_display_name("final") == "Finaal"
      assert Football.stage_display_name("final round") == "Finaalring"
    end

    test "returns original stage name for unknown stages" do
      assert Football.stage_display_name("Unknown Stage") == "Unknown Stage"
    end
  end

  describe "stage_short_name/1" do
    test "returns short names for known stages" do
      assert Football.stage_short_name("group stage") == "Grupp"
      assert Football.stage_short_name("round of 16") == "R16"
      assert Football.stage_short_name("quarter-finals") == "VF"
      assert Football.stage_short_name("semi-finals") == "PF"
      assert Football.stage_short_name("final") == "F"
    end
  end

  describe "competition management" do
    test "create_competition/1 creates a new competition" do
      {:ok, competition} =
        Football.create_competition(%{
          id: "test-comp-#{System.unique_integer([:positive])}",
          name: "Test Competition",
          short_name: "TC 2026",
          type: "world_cup",
          year: 2026
        })

      assert competition.name == "Test Competition"
      assert competition.type == "world_cup"
    end

    test "get_competition/1 returns a competition by id" do
      ensure_competition_exists()
      result = Football.get_competition("wc-2026")
      assert result != nil
      assert result.id == "wc-2026"
    end

    test "get_current_competition/0 returns current competition" do
      ensure_competition_exists()
      result = Football.get_current_competition()
      assert result != nil
    end

    test "list_competitions/0 returns all competitions" do
      ensure_competition_exists()
      result = Football.list_competitions()
      assert is_list(result)
      assert length(result) >= 1
    end

    test "list_active_competitions/0 returns only active competitions" do
      ensure_competition_exists()
      result = Football.list_active_competitions()
      assert is_list(result)
      Enum.each(result, fn c -> assert c.is_active == true end)
    end

    test "update_competition/2 updates a competition" do
      ensure_competition_exists()
      competition = Football.get_competition("wc-2026")

      {:ok, updated} =
        Football.update_competition(competition, %{short_name: "MM 2026 Updated"})

      assert updated.short_name == "MM 2026 Updated"
    end
  end

  describe "favorite teams" do
    test "add_favorite_team/3 adds a team to favorites" do
      user = user_fixture()
      team = team_fixture()

      {:ok, favorite} = Football.add_favorite_team(user.id, team.id)
      assert favorite.user_id == user.id
      assert favorite.team_id == team.id
      assert favorite.is_primary == false
    end

    test "add_favorite_team/3 with primary flag" do
      user = user_fixture()
      team = team_fixture()

      {:ok, favorite} = Football.add_favorite_team(user.id, team.id, true)
      assert favorite.is_primary == true
    end

    test "get_user_favorite_teams/1 returns user favorites" do
      user = user_fixture()
      team = team_fixture()

      Football.add_favorite_team(user.id, team.id)
      favorites = Football.get_user_favorite_teams(user.id)

      assert length(favorites) == 1
      assert hd(favorites).team_id == team.id
    end

    test "get_user_primary_team/1 returns primary team" do
      user = user_fixture()
      team1 = team_fixture()
      team2 = team_fixture()

      Football.add_favorite_team(user.id, team1.id, false)
      Football.add_favorite_team(user.id, team2.id, true)

      primary = Football.get_user_primary_team(user.id)
      assert primary != nil
      assert primary.team_id == team2.id
    end

    test "remove_favorite_team/2 removes a team from favorites" do
      user = user_fixture()
      team = team_fixture()

      Football.add_favorite_team(user.id, team.id)
      Football.remove_favorite_team(user.id, team.id)

      favorites = Football.get_user_favorite_teams(user.id)
      assert favorites == []
    end

    test "is_favorite_team?/2 checks if team is favorited" do
      user = user_fixture()
      team = team_fixture()

      refute Football.is_favorite_team?(user.id, team.id)
      Football.add_favorite_team(user.id, team.id)
      assert Football.is_favorite_team?(user.id, team.id)
    end

    test "set_primary_team/2 sets a team as primary" do
      user = user_fixture()
      team1 = team_fixture()
      team2 = team_fixture()

      Football.add_favorite_team(user.id, team1.id, true)
      Football.add_favorite_team(user.id, team2.id, false)

      Football.set_primary_team(user.id, team2.id)

      primary = Football.get_user_primary_team(user.id)
      assert primary.team_id == team2.id
    end

    test "get_favorite_teams_for_users/1 returns grouped favorites" do
      user1 = user_fixture()
      user2 = user_fixture()
      team = team_fixture()

      Football.add_favorite_team(user1.id, team.id)
      Football.add_favorite_team(user2.id, team.id)

      result = Football.get_favorite_teams_for_users([user1.id, user2.id])
      assert is_map(result)
      assert Map.has_key?(result, user1.id)
      assert Map.has_key?(result, user2.id)
    end
  end

  describe "rivalries" do
    test "add_rival/2 creates a rivalry" do
      user1 = user_fixture()
      user2 = user_fixture()

      {:ok, rivalry} = Football.add_rival(user1.id, user2.id)
      assert rivalry.user_id == user1.id
      assert rivalry.rival_id == user2.id
    end

    test "get_user_rivalries/1 returns user rivalries" do
      user1 = user_fixture()
      user2 = user_fixture()

      Football.add_rival(user1.id, user2.id)
      rivalries = Football.get_user_rivalries(user1.id)

      assert length(rivalries) == 1
      assert hd(rivalries).rival_id == user2.id
    end

    test "get_rivalry/2 returns specific rivalry" do
      user1 = user_fixture()
      user2 = user_fixture()

      Football.add_rival(user1.id, user2.id)
      rivalry = Football.get_rivalry(user1.id, user2.id)

      assert rivalry != nil
      assert rivalry.user_id == user1.id
    end

    test "remove_rival/2 removes a rivalry" do
      user1 = user_fixture()
      user2 = user_fixture()

      Football.add_rival(user1.id, user2.id)
      Football.remove_rival(user1.id, user2.id)

      assert Football.get_rivalry(user1.id, user2.id) == nil
    end

    test "is_rival?/2 checks rivalry existence" do
      user1 = user_fixture()
      user2 = user_fixture()

      refute Football.is_rival?(user1.id, user2.id)
      Football.add_rival(user1.id, user2.id)
      assert Football.is_rival?(user1.id, user2.id)
    end

    test "toggle_rivalry_notifications/2 toggles notification setting" do
      user1 = user_fixture()
      user2 = user_fixture()

      Football.add_rival(user1.id, user2.id)
      # Default is true
      rivalry = Football.get_rivalry(user1.id, user2.id)
      assert rivalry.notifications_enabled == true

      {:ok, updated} = Football.toggle_rivalry_notifications(user1.id, user2.id)
      assert updated.notifications_enabled == false
    end

    test "toggle_rivalry_notifications/2 returns error for non-existent rivalry" do
      user1 = user_fixture()
      user2 = user_fixture()

      assert {:error, :not_found} = Football.toggle_rivalry_notifications(user1.id, user2.id)
    end

    test "get_rivalries_with_notifications/1 returns only notified rivalries" do
      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()

      Football.add_rival(user1.id, user2.id)
      Football.add_rival(user1.id, user3.id)
      Football.toggle_rivalry_notifications(user1.id, user3.id)

      notified = Football.get_rivalries_with_notifications(user1.id)
      assert length(notified) == 1
      assert hd(notified).rival_id == user2.id
    end
  end

  describe "bracket predictions" do
    test "set_bracket_prediction/1 creates a new prediction" do
      user = user_fixture()
      team = team_fixture()

      {:ok, prediction} =
        Football.set_bracket_prediction(%{
          user_id: user.id,
          round: "round_of_16",
          position: 1,
          team_id: team.id
        })

      assert prediction.user_id == user.id
      assert prediction.team_id == team.id
      assert prediction.round == "round_of_16"
    end

    test "set_bracket_prediction/1 updates existing prediction" do
      user = user_fixture()
      team1 = team_fixture()
      team2 = team_fixture()

      Football.set_bracket_prediction(%{
        user_id: user.id,
        round: "round_of_16",
        position: 1,
        team_id: team1.id
      })

      {:ok, updated} =
        Football.set_bracket_prediction(%{
          user_id: user.id,
          round: "round_of_16",
          position: 1,
          team_id: team2.id
        })

      assert updated.team_id == team2.id
    end

    test "get_bracket_predictions_by_user/1 returns user predictions" do
      user = user_fixture()
      team = team_fixture()

      Football.set_bracket_prediction(%{
        user_id: user.id,
        round: "round_of_16",
        position: 1,
        team_id: team.id
      })

      predictions = Football.get_bracket_predictions_by_user(user.id)
      assert length(predictions) == 1
    end

    test "get_bracket_predictions_by_round/1 groups by round" do
      user = user_fixture()
      team1 = team_fixture()
      team2 = team_fixture()

      Football.set_bracket_prediction(%{
        user_id: user.id,
        round: "round_of_16",
        position: 1,
        team_id: team1.id
      })

      Football.set_bracket_prediction(%{
        user_id: user.id,
        round: "quarter_final",
        position: 1,
        team_id: team2.id
      })

      by_round = Football.get_bracket_predictions_by_round(user.id)
      assert is_map(by_round)
      assert Map.has_key?(by_round, "round_of_16")
      assert Map.has_key?(by_round, "quarter_final")
    end

    test "clear_bracket_prediction/3 removes a prediction" do
      user = user_fixture()
      team = team_fixture()

      Football.set_bracket_prediction(%{
        user_id: user.id,
        round: "round_of_16",
        position: 1,
        team_id: team.id
      })

      {:ok, _} = Football.clear_bracket_prediction(user.id, "round_of_16", 1)

      pred = Football.get_bracket_prediction(user.id, "round_of_16", 1)
      assert pred == nil
    end

    test "clear_bracket_prediction/3 returns ok for non-existent prediction" do
      user = user_fixture()
      assert {:ok, nil} = Football.clear_bracket_prediction(user.id, "round_of_16", 1)
    end

    test "cascade_bracket_removal/3 removes from later rounds" do
      user = user_fixture()
      team = team_fixture()

      Football.set_bracket_prediction(%{
        user_id: user.id, round: "round_of_16", position: 1, team_id: team.id
      })

      Football.set_bracket_prediction(%{
        user_id: user.id, round: "quarter_final", position: 1, team_id: team.id
      })

      Football.cascade_bracket_removal(user.id, team.id, "round_of_16")

      # quarter_final prediction should be removed
      assert Football.get_bracket_prediction(user.id, "quarter_final", 1) == nil
      # round_of_16 should still exist (cascade is from after the round)
    end
  end

  describe "bracket accuracy and points" do
    test "calculate_bracket_accuracy/1 returns correct structure" do
      user = user_fixture()
      accuracy = Football.calculate_bracket_accuracy(user.id)

      assert is_map(accuracy)
      assert Map.has_key?(accuracy, :by_round)
      assert Map.has_key?(accuracy, :total_correct)
      assert Map.has_key?(accuracy, :total_possible)
      assert Map.has_key?(accuracy, :overall_accuracy)
    end

    test "calculate_bracket_points/1 returns 0 for no predictions" do
      user = user_fixture()
      assert Football.calculate_bracket_points(user.id) == 0
    end
  end

  describe "prediction bias stats" do
    test "get_prediction_bias_stats/1 returns no-favorites result when no favorites" do
      user = user_fixture()
      stats = Football.get_prediction_bias_stats(user.id)

      assert stats.has_favorites == false
      assert stats.favorite_predictions == 0
      assert stats.other_predictions == 0
    end
  end

  describe "historical data" do
    test "get_historical_matchup/2 returns empty for non-existent teams" do
      result = Football.get_historical_matchup("NONEXISTENT1", "NONEXISTENT2")
      assert result == []
    end

    test "get_world_cup_matchup/2 returns empty for non-existent teams" do
      result = Football.get_world_cup_matchup("NONEXISTENT1", "NONEXISTENT2")
      assert result == []
    end

    test "get_historical_stats/2 returns zeros for non-existent teams" do
      stats = Football.get_historical_stats("NONEXISTENT1", "NONEXISTENT2")
      assert stats.total_matches == 0
      assert stats.team1_wins == 0
      assert stats.team2_wins == 0
      assert stats.draws == 0
    end

    test "get_team_recent_form/2 returns empty for non-existent teams" do
      assert Football.get_team_recent_form("NONEXISTENT") == []
    end

    test "get_team_world_cup_history/1 returns empty for non-existent teams" do
      assert Football.get_team_world_cup_history("NONEXISTENT") == []
    end

    test "get_team_world_cup_stats/1 returns zeros for non-existent teams" do
      stats = Football.get_team_world_cup_stats("NONEXISTENT")
      assert stats.matches_played == 0
      assert stats.wins == 0
    end

    test "get_team_world_cup_stats_by_tournament/1 returns empty for non-existent teams" do
      assert Football.get_team_world_cup_stats_by_tournament("NONEXISTENT") == []
    end

    test "get_team_world_cup_positions/1 returns zeros for non-existent teams" do
      positions = Football.get_team_world_cup_positions("NONEXISTENT")
      assert positions.counts.gold == 0
      assert positions.total_top_4 == 0
      assert positions.finishes == []
    end

    test "get_team_world_cup_eliminations/1 returns empty for non-existent teams" do
      result = Football.get_team_world_cup_eliminations("NONEXISTENT")
      assert result == %{}
    end
  end

  describe "differing predictions" do
    test "get_differing_predictions/2 returns empty when no predictions" do
      user1 = user_fixture()
      user2 = user_fixture()

      assert Football.get_differing_predictions(user1.id, user2.id) == []
    end

    test "get_differing_predictions/2 returns matches with different results" do
      user1 = user_fixture()
      user2 = user_fixture()
      match = match_fixture(%{finished: false})

      group_prediction_fixture(%{user: user1, match: match, home_score: 2, away_score: 0})
      group_prediction_fixture(%{user: user2, match: match, home_score: 0, away_score: 1})

      result = Football.get_differing_predictions(user1.id, user2.id)
      assert length(result) == 1
      assert hd(result).match.id == match.id
    end

    test "get_differing_predictions/2 skips same result predictions" do
      user1 = user_fixture()
      user2 = user_fixture()
      match = match_fixture(%{finished: false})

      # Both predict home win
      group_prediction_fixture(%{user: user1, match: match, home_score: 2, away_score: 0})
      group_prediction_fixture(%{user: user2, match: match, home_score: 3, away_score: 1})

      result = Football.get_differing_predictions(user1.id, user2.id)
      assert result == []
    end
  end

  describe "rivalry_stats" do
    test "get_rivalry_stats/2 returns stats for two users" do
      user1 = user_fixture()
      user2 = user_fixture()

      stats = Football.get_rivalry_stats(user1.id, user2.id)
      assert is_map(stats)
      assert Map.has_key?(stats, :user_group_points)
      assert Map.has_key?(stats, :rival_group_points)
      assert Map.has_key?(stats, :user_total_points)
      assert Map.has_key?(stats, :rival_total_points)
    end

    test "get_user_rivalries_with_stats/1 returns rivalries with stats" do
      user1 = user_fixture()
      user2 = user_fixture()

      Football.add_rival(user1.id, user2.id)
      result = Football.get_user_rivalries_with_stats(user1.id)

      assert length(result) == 1
      assert hd(result).rivalry != nil
      assert hd(result).stats != nil
    end

    test "get_rivalry!/1 returns rivalry with preloaded users" do
      user1 = user_fixture()
      user2 = user_fixture()

      {:ok, created} = Football.add_rival(user1.id, user2.id)
      rivalry = Football.get_rivalry!(created.id)
      assert rivalry.id == created.id
    end
  end

  describe "bracket results" do
    test "get_bracket_results/0 returns all bracket results" do
      result = Football.get_bracket_results()
      assert is_list(result)
    end

    test "get_bracket_results_by_round/0 returns grouped results" do
      result = Football.get_bracket_results_by_round()
      assert is_map(result)
    end

    test "set_bracket_result/1 creates a new result" do
      ensure_competition_exists()
      team = team_fixture()

      {:ok, result} =
        Football.set_bracket_result(%{
          round: "round_of_16",
          position: 1,
          team_id: team.id
        })

      assert result.round == "round_of_16"
      assert result.team_id == team.id
    end

    test "set_bracket_result/1 updates existing result" do
      ensure_competition_exists()
      team1 = team_fixture()
      team2 = team_fixture()

      Football.set_bracket_result(%{round: "round_of_16", position: 2, team_id: team1.id})

      {:ok, updated} =
        Football.set_bracket_result(%{round: "round_of_16", position: 2, team_id: team2.id})

      assert updated.team_id == team2.id
    end

    test "compare_brackets/2 returns comparison structure" do
      user1 = user_fixture()
      user2 = user_fixture()

      result = Football.compare_brackets(user1.id, user2.id)
      assert is_map(result)
      assert is_list(result.rounds)
      assert length(result.rounds) == 6  # 6 rounds
      assert Map.has_key?(result, :user1_points)
      assert Map.has_key?(result, :user2_points)
    end
  end

  describe "prediction bias with favorites" do
    test "get_prediction_bias_stats/1 returns stats with favorites" do
      user = user_fixture()
      team = team_fixture()
      Football.add_favorite_team(user.id, team.id)

      match = finished_match_fixture(%{home_team: team})
      group_prediction_fixture(%{user: user, match: match, home_score: 2, away_score: 1})

      stats = Football.get_prediction_bias_stats(user.id)
      assert stats.has_favorites == true
      assert stats.favorite_predictions >= 0
      assert stats.other_predictions >= 0
    end
  end

  describe "stage_display_name/1 additional" do
    test "translates second group stage" do
      assert Football.stage_display_name("second group stage") == "Teine alagrupifaas"
    end

    test "translates with mixed case" do
      assert Football.stage_display_name("Quarter-Finals") == "Veerandfinaal"
      assert Football.stage_display_name("Semi-Finals") == "Poolfinaal"
    end
  end

  describe "stage_short_name/1 additional" do
    test "translates additional stages" do
      assert Football.stage_short_name("second group stage") == "2. grupp"
      assert Football.stage_short_name("third-place match") == "3."
      assert Football.stage_short_name("final round") == "F"
    end
  end

end

defmodule Jalka2026.LeaderboardTest do
  use Jalka2026.DataCase

  import Jalka2026.FootballFixtures
  import Jalka2026.AccountsFixtures

  alias Jalka2026.Leaderboard
  alias Jalka2026.Leaderboard.Entry

  describe "point calculation logic" do
    test "user gets 1 point for correct result prediction" do
      user = user_fixture()
      home_team = team_fixture()
      away_team = team_fixture()

      # Create a finished match with home win (2-1)
      finished_match =
        finished_match_fixture(%{
          home_team: home_team,
          away_team: away_team,
          home_score: 2,
          away_score: 1
        })

      # User predicts home win but wrong score (3-0)
      _prediction =
        group_prediction_fixture(%{
          user: user,
          match: finished_match,
          home_score: 3,
          away_score: 0
        })

      # Recalculate and verify the user gets exactly 1 point
      leaderboard = Leaderboard.recalc_leaderboard()
      user_entry = Enum.find(leaderboard, fn %Entry{user_id: id} -> id == user.id end)
      assert user_entry != nil, "User should appear in leaderboard"

      assert user_entry.group_points == 1,
             "User should get 1 point for correct result but wrong score"
    end

    test "user gets 2 points for exact score prediction" do
      user = user_fixture()
      home_team = team_fixture()
      away_team = team_fixture()

      # Create a finished match with exact score
      finished_match =
        finished_match_fixture(%{
          home_team: home_team,
          away_team: away_team,
          home_score: 2,
          away_score: 1
        })

      # User predicts exact score
      _prediction =
        group_prediction_fixture(%{
          user: user,
          match: finished_match,
          home_score: 2,
          away_score: 1
        })

      # Recalculate and verify the user gets exactly 2 points
      leaderboard = Leaderboard.recalc_leaderboard()
      user_entry = Enum.find(leaderboard, fn %Entry{user_id: id} -> id == user.id end)
      assert user_entry != nil, "User should appear in leaderboard"
      assert user_entry.group_points == 2, "User should get 2 points for exact score prediction"
    end

    test "user gets 0 points for wrong result prediction" do
      user = user_fixture()
      home_team = team_fixture()
      away_team = team_fixture()

      # Create a finished match with home win
      finished_match =
        finished_match_fixture(%{
          home_team: home_team,
          away_team: away_team,
          home_score: 2,
          away_score: 1
        })

      # User predicts away win (wrong result)
      _prediction =
        group_prediction_fixture(%{
          user: user,
          match: finished_match,
          home_score: 0,
          away_score: 2
        })

      # Recalculate and verify the user gets 0 points
      leaderboard = Leaderboard.recalc_leaderboard()
      user_entry = Enum.find(leaderboard, fn %Entry{user_id: id} -> id == user.id end)
      assert user_entry != nil, "User should appear in leaderboard"
      assert user_entry.group_points == 0, "User should get 0 points for wrong result prediction"
    end
  end

  describe "playoff point values" do
    # Stored phases are the round-winner picks, so points are offset one stage from the phase
    # number: phase 32 = reached last-16 (2pt) ... phase 2 = tournament winner (8pt).
    test "phase 32 correct prediction awards 2 points" do
      user = user_fixture()
      team = team_fixture()

      playoff_prediction_fixture(%{user: user, team: team, phase: 32})
      playoff_result_fixture(%{team: team, phase: 32})

      leaderboard = Leaderboard.recalc_leaderboard()
      user_entry = Enum.find(leaderboard, fn %Entry{user_id: id} -> id == user.id end)
      assert user_entry != nil
      assert user_entry.playoff_points == 2, "Phase 32 correct prediction should award 2 points"
    end

    test "phase 16 correct prediction awards 3 points" do
      user = user_fixture()
      team = team_fixture()

      playoff_prediction_fixture(%{user: user, team: team, phase: 16})
      playoff_result_fixture(%{team: team, phase: 16})

      leaderboard = Leaderboard.recalc_leaderboard()
      user_entry = Enum.find(leaderboard, fn %Entry{user_id: id} -> id == user.id end)
      assert user_entry != nil
      assert user_entry.playoff_points == 3, "Phase 16 correct prediction should award 3 points"
    end

    test "phase 8 correct prediction awards 5 points" do
      user = user_fixture()
      team = team_fixture()

      playoff_prediction_fixture(%{user: user, team: team, phase: 8})
      playoff_result_fixture(%{team: team, phase: 8})

      leaderboard = Leaderboard.recalc_leaderboard()
      user_entry = Enum.find(leaderboard, fn %Entry{user_id: id} -> id == user.id end)
      assert user_entry != nil
      assert user_entry.playoff_points == 5, "Phase 8 correct prediction should award 5 points"
    end

    test "phase 4 correct prediction awards 6 points" do
      user = user_fixture()
      team = team_fixture()

      playoff_prediction_fixture(%{user: user, team: team, phase: 4})
      playoff_result_fixture(%{team: team, phase: 4})

      leaderboard = Leaderboard.recalc_leaderboard()
      user_entry = Enum.find(leaderboard, fn %Entry{user_id: id} -> id == user.id end)
      assert user_entry != nil
      assert user_entry.playoff_points == 6, "Phase 4 correct prediction should award 6 points"
    end

    test "phase 2 correct prediction awards 8 points" do
      user = user_fixture()
      team = team_fixture()

      playoff_prediction_fixture(%{user: user, team: team, phase: 2})
      playoff_result_fixture(%{team: team, phase: 2})

      leaderboard = Leaderboard.recalc_leaderboard()
      user_entry = Enum.find(leaderboard, fn %Entry{user_id: id} -> id == user.id end)
      assert user_entry != nil
      assert user_entry.playoff_points == 8, "Phase 2 correct prediction should award 8 points"
    end

    test "incorrect playoff prediction awards 0 playoff points" do
      user = user_fixture()
      team = team_fixture()
      other_team = team_fixture()

      # User predicts team, but other_team advances
      playoff_prediction_fixture(%{user: user, team: team, phase: 32})
      playoff_result_fixture(%{team: other_team, phase: 32})

      leaderboard = Leaderboard.recalc_leaderboard()
      user_entry = Enum.find(leaderboard, fn %Entry{user_id: id} -> id == user.id end)
      assert user_entry != nil
      assert user_entry.playoff_points == 0, "Incorrect playoff prediction should award 0 points"
    end
  end

  describe "draw predictions" do
    test "draw result is correctly calculated" do
      user = user_fixture()
      home_team = team_fixture()
      away_team = team_fixture()

      # Create a finished match with draw
      finished_match =
        finished_match_fixture(%{
          home_team: home_team,
          away_team: away_team,
          home_score: 1,
          away_score: 1
        })

      # User predicts draw
      _prediction =
        group_prediction_fixture(%{
          user: user,
          match: finished_match,
          home_score: 2,
          away_score: 2
        })

      prediction = Jalka2026.Football.get_prediction_by_user_match(user.id, finished_match.id)
      assert prediction.result == "draw"
      assert finished_match.result == "draw"
    end
  end

  describe "incomplete group prediction filter" do
    setup do
      original = Application.get_env(:jalka2026, :leaderboard_required_predictions)

      on_exit(fn ->
        Application.put_env(:jalka2026, :leaderboard_required_predictions, original)
      end)

      :ok
    end

    test "users below the required prediction count are removed from the leaderboard" do
      Application.put_env(:jalka2026, :leaderboard_required_predictions, 2)

      complete_user = user_fixture()
      incomplete_user = user_fixture()

      match1 = finished_match_fixture(%{home_score: 2, away_score: 1})
      match2 = finished_match_fixture(%{home_score: 1, away_score: 1})

      group_prediction_fixture(%{
        user: complete_user,
        match: match1,
        home_score: 2,
        away_score: 1
      })

      group_prediction_fixture(%{
        user: complete_user,
        match: match2,
        home_score: 1,
        away_score: 1
      })

      group_prediction_fixture(%{
        user: incomplete_user,
        match: match1,
        home_score: 2,
        away_score: 1
      })

      leaderboard = Leaderboard.recalc_leaderboard()

      assert Enum.find(leaderboard, fn %Entry{user_id: id} -> id == complete_user.id end),
             "User with all required predictions should appear in leaderboard"

      refute Enum.find(leaderboard, fn %Entry{user_id: id} -> id == incomplete_user.id end),
             "User with incomplete group predictions should not appear in leaderboard"
    end

    test "users with no predictions are removed from the leaderboard" do
      Application.put_env(:jalka2026, :leaderboard_required_predictions, 1)

      user = user_fixture()

      leaderboard = Leaderboard.recalc_leaderboard()

      refute Enum.find(leaderboard, fn %Entry{user_id: id} -> id == user.id end),
             "User with no predictions should not appear in leaderboard"
    end
  end

  describe "GenServer interface" do
    test "subscribe/0 subscribes to leaderboard updates" do
      assert :ok = Leaderboard.subscribe()
    end
  end
end

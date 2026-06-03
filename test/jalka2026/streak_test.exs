defmodule Jalka2026.StreakTest do
  use Jalka2026.DataCase

  alias Jalka2026.Streak
  import Jalka2026.AccountsFixtures
  import Jalka2026.FootballFixtures

  describe "calculate_streak_stats/2" do
    test "returns zeros with no finished matches" do
      {current, longest} = Streak.calculate_streak_stats([], %{})
      assert current == 0
      assert longest == 0
    end

    test "counts consecutive correct predictions" do
      match1 = %{id: 1, result: "home"}
      match2 = %{id: 2, result: "away"}
      match3 = %{id: 3, result: "draw"}

      predictions = %{
        1 => %{result: "home"},
        2 => %{result: "away"},
        3 => %{result: "draw"}
      }

      {current, longest} =
        Streak.calculate_streak_stats([match1, match2, match3], predictions)

      assert current == 3
      assert longest == 3
    end

    test "resets streak on wrong prediction" do
      match1 = %{id: 1, result: "home"}
      match2 = %{id: 2, result: "away"}
      match3 = %{id: 3, result: "draw"}

      predictions = %{
        1 => %{result: "home"},
        # Wrong
        2 => %{result: "home"},
        3 => %{result: "draw"}
      }

      {current, longest} =
        Streak.calculate_streak_stats([match1, match2, match3], predictions)

      assert current == 1
      assert longest == 1
    end

    test "handles nil predictions (no prediction for match)" do
      matches = [%{id: 1, result: "home"}, %{id: 2, result: "away"}]
      predictions = %{1 => %{result: "home"}}

      {current, longest} = Streak.calculate_streak_stats(matches, predictions)
      assert current == 0
      assert longest == 1
    end

    test "tracks longest streak even after break" do
      matches = for i <- 1..8, do: %{id: i, result: "home"}

      predictions = %{
        1 => %{result: "home"},
        2 => %{result: "home"},
        3 => %{result: "home"},
        # Break at 4
        4 => %{result: "away"},
        5 => %{result: "home"},
        6 => %{result: "home"},
        7 => %{result: "home"},
        8 => %{result: "home"}
      }

      {current, longest} = Streak.calculate_streak_stats(matches, predictions)
      assert current == 4
      assert longest == 4
    end
  end

  describe "get_or_create_streak/1" do
    test "creates a new streak if none exists" do
      user = user_fixture()
      streak = Streak.get_or_create_streak(user.id)

      assert streak.user_id == user.id
      assert streak.current_streak == 0
      assert streak.longest_streak == 0
    end

    test "returns existing streak" do
      user = user_fixture()
      _first = Streak.get_or_create_streak(user.id)
      second = Streak.get_or_create_streak(user.id)

      assert second.user_id == user.id
    end
  end

  describe "get_user_streak/1" do
    test "returns zeros for user with no streak record" do
      user = user_fixture()
      result = Streak.get_user_streak(user.id)
      assert result.current_streak == 0
      assert result.longest_streak == 0
    end
  end

  describe "get_all_streaks/0" do
    test "returns map of user streaks" do
      result = Streak.get_all_streaks()
      assert is_map(result)
    end
  end

  describe "calculate_and_save_streak/2" do
    test "saves streak data for a user" do
      user = user_fixture()
      finished_matches = []

      result = Streak.calculate_and_save_streak(user.id, finished_matches)

      assert result.current_streak == 0
      assert result.longest_streak == 0
    end

    test "calculates and saves correct streak" do
      user = user_fixture()
      match = finished_match_fixture(%{home_score: 2, away_score: 1})

      # Create prediction matching the result
      group_prediction_fixture(%{
        user: user,
        match: match,
        home_score: 3,
        # Different score but same result (home)
        away_score: 0
      })

      result = Streak.calculate_and_save_streak(user.id, [match])
      assert result.current_streak == 1
      assert result.longest_streak == 1
    end
  end

  describe "recalculate_all_streaks/0" do
    test "recalculates streaks for all users" do
      user = user_fixture()
      match = finished_match_fixture(%{home_score: 2, away_score: 1})

      group_prediction_fixture(%{
        user: user,
        match: match,
        home_score: 3,
        away_score: 0
      })

      result = Streak.recalculate_all_streaks()

      assert is_map(result)
      assert Map.has_key?(result, user.id)
      assert result[user.id].current_streak == 1
      assert result[user.id].longest_streak == 1
    end

    test "handles users with no predictions" do
      user = user_fixture()
      _match = finished_match_fixture(%{home_score: 2, away_score: 1})

      result = Streak.recalculate_all_streaks()

      assert is_map(result)
      assert Map.has_key?(result, user.id)
      assert result[user.id].current_streak == 0
    end
  end

  describe "recalculate_all_streaks/3" do
    test "recalculates streaks using pre-loaded data" do
      user = user_fixture()
      match = finished_match_fixture(%{home_score: 2, away_score: 1})

      prediction =
        group_prediction_fixture(%{
          user: user,
          match: match,
          home_score: 3,
          away_score: 0
        })

      predictions_by_user = %{
        user.id => %{match.id => prediction}
      }

      result = Streak.recalculate_all_streaks([user], [match], predictions_by_user)

      assert is_map(result)
      assert Map.has_key?(result, user.id)
      assert result[user.id].current_streak == 1
    end

    test "creates new streak records for users without existing ones" do
      user = user_fixture()

      result = Streak.recalculate_all_streaks([user], [], %{})

      assert is_map(result)
      assert Map.has_key?(result, user.id)
      assert result[user.id].current_streak == 0
    end

    test "updates existing streak records" do
      user = user_fixture()
      # Create initial streak
      _initial = Streak.get_or_create_streak(user.id)

      match = finished_match_fixture(%{home_score: 1, away_score: 0})

      prediction =
        group_prediction_fixture(%{
          user: user,
          match: match,
          home_score: 2,
          away_score: 0
        })

      result =
        Streak.recalculate_all_streaks(
          [user],
          [match],
          %{user.id => %{match.id => prediction}}
        )

      assert result[user.id].current_streak == 1
    end
  end
end

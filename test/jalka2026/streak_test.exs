defmodule Jalka2026.StreakTest do
  use Jalka2026.DataCase

  alias Jalka2026.Streak
  import Jalka2026.AccountsFixtures
  import Jalka2026.FootballFixtures

  describe "calculate_streak_stats/2" do
    test "returns zeros with no finished matches" do
      {current, longest, bonus} = Streak.calculate_streak_stats([], %{})
      assert current == 0
      assert longest == 0
      assert bonus == 0
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

      {current, longest, bonus} = Streak.calculate_streak_stats([match1, match2, match3], predictions)
      assert current == 3
      assert longest == 3
      assert bonus == 0
    end

    test "resets streak on wrong prediction" do
      match1 = %{id: 1, result: "home"}
      match2 = %{id: 2, result: "away"}
      match3 = %{id: 3, result: "draw"}

      predictions = %{
        1 => %{result: "home"},
        2 => %{result: "home"},  # Wrong
        3 => %{result: "draw"}
      }

      {current, longest, bonus} = Streak.calculate_streak_stats([match1, match2, match3], predictions)
      assert current == 1
      assert longest == 1
      assert bonus == 0
    end

    test "awards bonus points for streaks of 5+" do
      matches = for i <- 1..7, do: %{id: i, result: "home"}
      predictions = for i <- 1..7, into: %{}, do: {i, %{result: "home"}}

      {current, longest, bonus} = Streak.calculate_streak_stats(matches, predictions)
      assert current == 7
      assert longest == 7
      # Streak of 5 gets +1, 6 gets +1, 7 gets +1 = 3 total
      assert bonus == 3
    end

    test "handles nil predictions (no prediction for match)" do
      matches = [%{id: 1, result: "home"}, %{id: 2, result: "away"}]
      predictions = %{1 => %{result: "home"}}

      {current, longest, bonus} = Streak.calculate_streak_stats(matches, predictions)
      assert current == 0
      assert longest == 1
      assert bonus == 0
    end

    test "tracks longest streak even after break" do
      matches = for i <- 1..8, do: %{id: i, result: "home"}

      predictions = %{
        1 => %{result: "home"},
        2 => %{result: "home"},
        3 => %{result: "home"},
        4 => %{result: "away"},  # Break at 4
        5 => %{result: "home"},
        6 => %{result: "home"},
        7 => %{result: "home"},
        8 => %{result: "home"}
      }

      {current, longest, _bonus} = Streak.calculate_streak_stats(matches, predictions)
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
      assert streak.bonus_points == 0
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
      assert result.bonus_points == 0
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
      assert result.bonus_points == 0
    end

    test "calculates and saves correct streak" do
      user = user_fixture()
      match = finished_match_fixture(%{home_score: 2, away_score: 1})

      # Create prediction matching the result
      group_prediction_fixture(%{
        user: user,
        match: match,
        home_score: 3,
        away_score: 0  # Different score but same result (home)
      })

      result = Streak.calculate_and_save_streak(user.id, [match])
      assert result.current_streak == 1
      assert result.longest_streak == 1
    end
  end
end

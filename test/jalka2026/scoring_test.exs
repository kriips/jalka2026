defmodule Jalka2026.ScoringTest do
  use ExUnit.Case, async: true

  alias Jalka2026.Scoring

  describe "group_match_points/2" do
    test "returns 2 for exact score prediction" do
      match = %{result: "home", home_score: 2, away_score: 1}
      prediction = %{result: "home", home_score: 2, away_score: 1}
      assert Scoring.group_match_points(match, prediction) == 2
    end

    test "returns 1 for correct result but wrong score" do
      match = %{result: "home", home_score: 2, away_score: 1}
      prediction = %{result: "home", home_score: 3, away_score: 0}
      assert Scoring.group_match_points(match, prediction) == 1
    end

    test "returns 0 for wrong result" do
      match = %{result: "home", home_score: 2, away_score: 1}
      prediction = %{result: "away", home_score: 0, away_score: 2}
      assert Scoring.group_match_points(match, prediction) == 0
    end

    test "returns 0 for nil prediction" do
      match = %{result: "home", home_score: 2, away_score: 1}
      assert Scoring.group_match_points(match, nil) == 0
    end

    test "handles draw exact score" do
      match = %{result: "draw", home_score: 1, away_score: 1}
      prediction = %{result: "draw", home_score: 1, away_score: 1}
      assert Scoring.group_match_points(match, prediction) == 2
    end

    test "handles draw correct result wrong score" do
      match = %{result: "draw", home_score: 1, away_score: 1}
      prediction = %{result: "draw", home_score: 0, away_score: 0}
      assert Scoring.group_match_points(match, prediction) == 1
    end

    test "handles away win exact score" do
      match = %{result: "away", home_score: 0, away_score: 3}
      prediction = %{result: "away", home_score: 0, away_score: 3}
      assert Scoring.group_match_points(match, prediction) == 2
    end

    test "handles 0-0 draw" do
      match = %{result: "draw", home_score: 0, away_score: 0}
      prediction = %{result: "draw", home_score: 0, away_score: 0}
      assert Scoring.group_match_points(match, prediction) == 2
    end

    test "correct result but predicting draw vs home gives 0" do
      match = %{result: "home", home_score: 1, away_score: 0}
      prediction = %{result: "draw", home_score: 1, away_score: 1}
      assert Scoring.group_match_points(match, prediction) == 0
    end
  end

  describe "total_group_points/3" do
    test "sums points across multiple matches" do
      matches = [
        %{id: 1, result: "home", home_score: 2, away_score: 1},
        %{id: 2, result: "away", home_score: 0, away_score: 1},
        %{id: 3, result: "draw", home_score: 1, away_score: 1}
      ]

      predictions_index = %{
        # exact: 2pts
        {42, 1} => %{result: "home", home_score: 2, away_score: 1},
        # correct result: 1pt
        {42, 2} => %{result: "away", home_score: 0, away_score: 2},
        # wrong: 0pts
        {42, 3} => %{result: "home", home_score: 2, away_score: 0}
      }

      assert Scoring.total_group_points(matches, predictions_index, 42) == 3
    end

    test "returns 0 when no predictions exist" do
      matches = [%{id: 1, result: "home", home_score: 2, away_score: 1}]
      assert Scoring.total_group_points(matches, %{}, 42) == 0
    end

    test "returns 0 with no matches" do
      assert Scoring.total_group_points([], %{}, 42) == 0
    end
  end

  describe "playoff_phase_points/1" do
    test "round of 32 awards 1 point" do
      assert Scoring.playoff_phase_points(32) == 1
    end

    test "round of 16 awards 2 points" do
      assert Scoring.playoff_phase_points(16) == 2
    end

    test "quarter-finals award 3 points" do
      assert Scoring.playoff_phase_points(8) == 3
    end

    test "semi-finals award 5 points" do
      assert Scoring.playoff_phase_points(4) == 5
    end

    test "final awards 6 points" do
      assert Scoring.playoff_phase_points(2) == 6
    end
  end

  describe "total_playoff_points/2" do
    test "sums correct predictions across phases" do
      playoff_results = [
        %{team_id: 100, phase: 32},
        %{team_id: 101, phase: 16},
        %{team_id: 100, phase: 8}
      ]

      predictions = %{
        # correct: team 100
        32 => [100, 102],
        # correct: team 101
        16 => [101],
        # wrong: predicted 103 not 100
        8 => [103]
      }

      # 1 (phase 32) + 2 (phase 16) = 3
      assert Scoring.total_playoff_points(playoff_results, predictions) == 3
    end

    test "returns 0 with no matching predictions" do
      playoff_results = [%{team_id: 100, phase: 32}]
      predictions = %{32 => [999]}
      assert Scoring.total_playoff_points(playoff_results, predictions) == 0
    end

    test "returns 0 with empty predictions" do
      playoff_results = [%{team_id: 100, phase: 32}]
      assert Scoring.total_playoff_points(playoff_results, %{}) == 0
    end

    test "returns 0 with nil predictions" do
      playoff_results = [%{team_id: 100, phase: 32}]
      assert Scoring.total_playoff_points(playoff_results, nil) == 0
    end

    test "handles multiple correct predictions in same phase" do
      playoff_results = [
        %{team_id: 100, phase: 32},
        %{team_id: 101, phase: 32}
      ]

      predictions = %{32 => [100, 101]}
      # 1 + 1 = 2
      assert Scoring.total_playoff_points(playoff_results, predictions) == 2
    end

    test "sums all phases for perfect predictions" do
      playoff_results = [
        %{team_id: 1, phase: 32},
        %{team_id: 1, phase: 16},
        %{team_id: 1, phase: 8},
        %{team_id: 1, phase: 4},
        %{team_id: 1, phase: 2}
      ]

      predictions = %{
        32 => [1],
        16 => [1],
        8 => [1],
        4 => [1],
        2 => [1]
      }

      # 1 + 2 + 3 + 5 + 6 = 17
      assert Scoring.total_playoff_points(playoff_results, predictions) == 17
    end
  end

  describe "calculate_result/2" do
    test "home win" do
      assert Scoring.calculate_result(2, 1) == "home"
    end

    test "away win" do
      assert Scoring.calculate_result(0, 1) == "away"
    end

    test "draw" do
      assert Scoring.calculate_result(1, 1) == "draw"
    end

    test "0-0 draw" do
      assert Scoring.calculate_result(0, 0) == "draw"
    end

    test "high-scoring home win" do
      assert Scoring.calculate_result(5, 3) == "home"
    end
  end

  describe "streak_bonus_increment/1" do
    test "returns 0 for streak < 5" do
      for i <- 0..4 do
        assert Scoring.streak_bonus_increment(i) == 0
      end
    end

    test "returns 1 for streak >= 5" do
      for i <- 5..10 do
        assert Scoring.streak_bonus_increment(i) == 1
      end
    end
  end

  describe "prediction_correct?/2" do
    test "returns true for matching result" do
      assert Scoring.prediction_correct?(%{result: "home"}, %{result: "home"})
    end

    test "returns false for different result" do
      refute Scoring.prediction_correct?(%{result: "home"}, %{result: "away"})
    end

    test "returns false for nil prediction" do
      refute Scoring.prediction_correct?(%{result: "home"}, nil)
    end
  end

  describe "calculate_streak_stats/2" do
    test "returns zeros with no matches" do
      assert Scoring.calculate_streak_stats([], %{}) == {0, 0, 0}
    end

    test "counts consecutive correct predictions" do
      matches = [
        %{id: 1, result: "home"},
        %{id: 2, result: "away"},
        %{id: 3, result: "draw"}
      ]

      predictions = %{
        1 => %{result: "home"},
        2 => %{result: "away"},
        3 => %{result: "draw"}
      }

      assert Scoring.calculate_streak_stats(matches, predictions) == {3, 3, 0}
    end

    test "resets streak on wrong prediction" do
      matches = [
        %{id: 1, result: "home"},
        %{id: 2, result: "away"},
        %{id: 3, result: "draw"}
      ]

      predictions = %{
        1 => %{result: "home"},
        # Wrong
        2 => %{result: "home"},
        3 => %{result: "draw"}
      }

      assert Scoring.calculate_streak_stats(matches, predictions) == {1, 1, 0}
    end

    test "awards bonus points for streaks of 5+" do
      matches = for i <- 1..7, do: %{id: i, result: "home"}
      predictions = for i <- 1..7, into: %{}, do: {i, %{result: "home"}}

      {current, longest, bonus} = Scoring.calculate_streak_stats(matches, predictions)
      assert current == 7
      assert longest == 7
      # Streak of 5 gets +1, 6 gets +1, 7 gets +1 = 3 total
      assert bonus == 3
    end

    test "handles nil predictions (no prediction for match)" do
      matches = [%{id: 1, result: "home"}, %{id: 2, result: "away"}]
      predictions = %{1 => %{result: "home"}}

      assert Scoring.calculate_streak_stats(matches, predictions) == {0, 1, 0}
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

      {current, longest, _bonus} = Scoring.calculate_streak_stats(matches, predictions)
      assert current == 4
      assert longest == 4
    end

    test "bonus only counts from threshold onward" do
      matches = for i <- 1..5, do: %{id: i, result: "home"}
      predictions = for i <- 1..5, into: %{}, do: {i, %{result: "home"}}

      {_current, _longest, bonus} = Scoring.calculate_streak_stats(matches, predictions)
      # Only the 5th match triggers bonus
      assert bonus == 1
    end

    test "bonus accumulates across long streak" do
      matches = for i <- 1..10, do: %{id: i, result: "home"}
      predictions = for i <- 1..10, into: %{}, do: {i, %{result: "home"}}

      {current, longest, bonus} = Scoring.calculate_streak_stats(matches, predictions)
      assert current == 10
      assert longest == 10
      # Matches 5-10 get bonus: 6 bonus points
      assert bonus == 6
    end

    test "bonus does not carry over after break" do
      matches = for i <- 1..12, do: %{id: i, result: "home"}

      predictions =
        Map.merge(
          for(i <- 1..6, into: %{}, do: {i, %{result: "home"}}),
          Map.merge(
            # Break
            %{7 => %{result: "away"}},
            for(i <- 8..12, into: %{}, do: {i, %{result: "home"}})
          )
        )

      {current, longest, bonus} = Scoring.calculate_streak_stats(matches, predictions)
      assert current == 5
      assert longest == 6
      # First streak: 5th=+1, 6th=+1 = 2
      # Second streak: 12th (5th in streak)=+1 = 1
      assert bonus == 3
    end
  end

  describe "calculate/2" do
    test "group scoring delegates to group_match_points" do
      match = %{result: "home", home_score: 2, away_score: 1}
      exact = %{result: "home", home_score: 2, away_score: 1}
      correct = %{result: "home", home_score: 3, away_score: 0}
      wrong = %{result: "away", home_score: 0, away_score: 2}

      assert Scoring.calculate(:group, {match, exact}) == 2
      assert Scoring.calculate(:group, {match, correct}) == 1
      assert Scoring.calculate(:group, {match, wrong}) == 0
      assert Scoring.calculate(:group, {match, nil}) == 0
    end

    test "playoff scoring delegates to playoff_phase_points" do
      assert Scoring.calculate(:playoff, 32) == 1
      assert Scoring.calculate(:playoff, 16) == 2
      assert Scoring.calculate(:playoff, 8) == 3
      assert Scoring.calculate(:playoff, 4) == 5
      assert Scoring.calculate(:playoff, 2) == 6
    end
  end

  describe "playoff_phase_points_map/0" do
    test "returns the complete phase-to-points mapping" do
      map = Scoring.playoff_phase_points_map()
      assert map == %{32 => 1, 16 => 2, 8 => 3, 4 => 5, 2 => 6}
    end

    test "is consistent with playoff_phase_points/1" do
      for {phase, points} <- Scoring.playoff_phase_points_map() do
        assert Scoring.playoff_phase_points(phase) == points
      end
    end
  end

  describe "phases/0" do
    test "returns all playoff phases in order" do
      assert Scoring.phases() == [32, 16, 8, 4, 2]
    end
  end
end

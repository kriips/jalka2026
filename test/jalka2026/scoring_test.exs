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
    # Stored phases are round-winner picks, so points are offset one stage from the phase number:
    # phase 32 = reached last-16 (2pt), phase 16 = QF (3pt), ... phase 2 = winner (8pt).
    test "phase 32 (reached last-16) awards 2 points" do
      assert Scoring.playoff_phase_points(32) == 2
    end

    test "phase 16 (reached quarter-final) awards 3 points" do
      assert Scoring.playoff_phase_points(16) == 3
    end

    test "phase 8 (reached semi-final) awards 5 points" do
      assert Scoring.playoff_phase_points(8) == 5
    end

    test "phase 4 (finalist) awards 6 points" do
      assert Scoring.playoff_phase_points(4) == 6
    end

    test "phase 2 (winner) awards 8 points" do
      assert Scoring.playoff_phase_points(2) == 8
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

      # 2 (phase 32) + 3 (phase 16) = 5
      assert Scoring.total_playoff_points(playoff_results, predictions) == 5
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
      # 2 + 2 = 4
      assert Scoring.total_playoff_points(playoff_results, predictions) == 4
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

      # 2 + 3 + 5 + 6 + 8 = 24
      assert Scoring.total_playoff_points(playoff_results, predictions) == 24
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
      assert Scoring.calculate_streak_stats([], %{}) == {0, 0}
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

      assert Scoring.calculate_streak_stats(matches, predictions) == {3, 3}
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

      assert Scoring.calculate_streak_stats(matches, predictions) == {1, 1}
    end

    test "handles nil predictions (no prediction for match)" do
      matches = [%{id: 1, result: "home"}, %{id: 2, result: "away"}]
      predictions = %{1 => %{result: "home"}}

      assert Scoring.calculate_streak_stats(matches, predictions) == {0, 1}
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

      {current, longest} = Scoring.calculate_streak_stats(matches, predictions)
      assert current == 4
      assert longest == 4
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
      assert Scoring.calculate(:playoff, 32) == 2
      assert Scoring.calculate(:playoff, 16) == 3
      assert Scoring.calculate(:playoff, 8) == 5
      assert Scoring.calculate(:playoff, 4) == 6
      assert Scoring.calculate(:playoff, 2) == 8
    end
  end

  describe "playoff_phase_points_map/0" do
    test "returns the complete phase-to-points mapping" do
      map = Scoring.playoff_phase_points_map()
      assert map == %{32 => 2, 16 => 3, 8 => 5, 4 => 6, 2 => 8}
    end

    test "is consistent with playoff_phase_points/1" do
      for {phase, points} <- Scoring.playoff_phase_points_map() do
        assert Scoring.playoff_phase_points(phase) == points
      end
    end
  end

  describe "last_32_points/2" do
    test "awards 1 point per correctly-predicted last-32 qualifier" do
      # predicted teams 1,2,3,4; teams 2,3,5 actually reached -> overlap {2,3} = 2 points
      assert Scoring.last_32_points([1, 2, 3, 4], [2, 3, 5]) == 2
    end

    test "returns 0 when nothing overlaps" do
      assert Scoring.last_32_points([1, 2], [3, 4]) == 0
    end

    test "returns 0 for empty predicted or actual sets" do
      assert Scoring.last_32_points([], [1, 2]) == 0
      assert Scoring.last_32_points([1, 2], []) == 0
    end

    test "accepts MapSet inputs and ignores duplicates" do
      assert Scoring.last_32_points(MapSet.new([1, 1, 2]), MapSet.new([2, 2, 9])) == 1
    end
  end

  describe "phases/0" do
    test "returns all playoff phases in order" do
      assert Scoring.phases() == [32, 16, 8, 4, 2]
    end
  end
end

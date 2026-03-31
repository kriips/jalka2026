defmodule Jalka2026.Football.MatchSimulationTest do
  use Jalka2026.DataCase

  alias Jalka2026.Football.MatchSimulation

  describe "poisson_random/1" do
    test "returns 0 for lambda <= 0" do
      assert MatchSimulation.poisson_random(0) == 0
      assert MatchSimulation.poisson_random(-1) == 0
    end

    test "returns non-negative integers for positive lambda" do
      for _ <- 1..100 do
        result = MatchSimulation.poisson_random(1.5)
        assert is_integer(result)
        assert result >= 0
      end
    end

    test "average converges to lambda for large samples" do
      lambda = 2.0
      samples = for _ <- 1..10_000, do: MatchSimulation.poisson_random(lambda)
      avg = Enum.sum(samples) / length(samples)
      # Should be within reasonable range of lambda
      assert abs(avg - lambda) < 1.5
    end
  end

  describe "calculate_expected_goals/3" do
    test "returns positive goals value" do
      result = MatchSimulation.calculate_expected_goals(1.0, 1.0, true)
      assert result > 0
    end

    test "home team gets higher expected goals with home advantage" do
      home_goals = MatchSimulation.calculate_expected_goals(1.0, 1.0, true)
      away_goals = MatchSimulation.calculate_expected_goals(1.0, 1.0, false)
      assert home_goals > away_goals
    end

    test "stronger team gets more expected goals" do
      strong = MatchSimulation.calculate_expected_goals(1.3, 0.8, true)
      weak = MatchSimulation.calculate_expected_goals(0.8, 1.3, true)
      assert strong > weak
    end
  end

  describe "run_simulations/3" do
    test "returns correct number of results" do
      results = MatchSimulation.run_simulations(100, 1.5, 1.2)
      assert length(results) == 100
    end

    test "results are tuples of non-negative integers" do
      results = MatchSimulation.run_simulations(50, 1.5, 1.2)

      Enum.each(results, fn {home, away} ->
        assert is_integer(home) and home >= 0
        assert is_integer(away) and away >= 0
      end)
    end
  end

  describe "aggregate_results/4" do
    test "returns correct structure" do
      results = [{2, 1}, {1, 1}, {0, 3}, {2, 0}, {1, 1}]
      aggregated = MatchSimulation.aggregate_results(results, 5, 1.0, 0.9)

      assert aggregated.simulations == 5
      assert is_float(aggregated.home_win_pct)
      assert is_float(aggregated.draw_pct)
      assert is_float(aggregated.away_win_pct)
      assert is_float(aggregated.avg_home_goals)
      assert is_float(aggregated.avg_away_goals)
      assert is_float(aggregated.team1_strength)
      assert is_float(aggregated.team2_strength)
      assert is_map(aggregated.score_distribution)
      assert is_list(aggregated.most_likely_scores)
    end

    test "percentages sum to approximately 100" do
      results = [{2, 1}, {1, 1}, {0, 3}, {2, 0}, {1, 1}]
      aggregated = MatchSimulation.aggregate_results(results, 5, 1.0, 0.9)

      total = aggregated.home_win_pct + aggregated.draw_pct + aggregated.away_win_pct
      assert_in_delta total, 100.0, 0.5
    end

    test "correct outcome counts" do
      # 2 home wins, 2 draws, 1 away win
      results = [{2, 1}, {1, 1}, {0, 3}, {2, 0}, {1, 1}]
      aggregated = MatchSimulation.aggregate_results(results, 5, 1.0, 0.9)

      assert aggregated.home_win_pct == 40.0
      assert aggregated.draw_pct == 40.0
      assert aggregated.away_win_pct == 20.0
    end
  end

  describe "generate_score_matrix/2" do
    test "returns 6x6 matrix" do
      score_counts = %{{1, 0} => 5, {0, 0} => 3, {2, 1} => 2}
      matrix = MatchSimulation.generate_score_matrix(score_counts, 10)

      assert length(matrix) == 6
      Enum.each(matrix, fn row ->
        assert length(row) == 6
      end)
    end

    test "matrix cells have correct structure" do
      score_counts = %{{1, 0} => 5}
      matrix = MatchSimulation.generate_score_matrix(score_counts, 10)

      cell = matrix |> Enum.at(1) |> Enum.at(0)
      assert cell.home_goals == 1
      assert cell.away_goals == 0
      assert cell.count == 5
      assert cell.percentage == 50.0
    end
  end

  describe "calculate_form_strength/1" do
    test "returns 1.0 for teams with no form data" do
      result = MatchSimulation.calculate_form_strength("NONEXISTENT")
      assert result == 1.0
    end

    test "returns a non-default value for teams with real historical data" do
      # BRA has historical match data in the test DB
      result = MatchSimulation.calculate_form_strength("BRA")
      # Should differ from the default 1.0 neutral strength
      assert is_float(result)
      # BRA actually won matches, so form strength should deviate from the 1.0 default
      assert result != 1.0, "Expected BRA to have a non-default form strength based on historical data"
    end
  end

  describe "calculate_h2h_strength/2" do
    test "returns 1.0 for teams with no history" do
      result = MatchSimulation.calculate_h2h_strength("NONEXISTENT1", "NONEXISTENT2")
      assert result == 1.0
    end

    test "returns non-default value for teams with head-to-head history" do
      # BRA vs ARG have historical matches
      result = MatchSimulation.calculate_h2h_strength("BRA", "ARG")
      assert is_float(result)
      assert result != 1.0, "Expected BRA vs ARG to have non-default h2h strength"
    end
  end

  describe "calculate_wc_strength/1" do
    test "returns 0.9 for teams without WC history" do
      result = MatchSimulation.calculate_wc_strength("NONEXISTENT")
      assert result == 0.9
    end

    test "returns non-default value for teams with WC history" do
      # BRA has World Cup historical data
      result = MatchSimulation.calculate_wc_strength("BRA")
      assert is_float(result)
      assert result != 0.9, "Expected BRA to have a non-default WC strength based on historical data"
    end
  end

  describe "calculate_base_strength/1" do
    test "returns 1.0 for teams with no data" do
      result = MatchSimulation.calculate_base_strength("NONEXISTENT")
      assert result == 1.0
    end

    test "returns non-default value for teams with real historical data" do
      result = MatchSimulation.calculate_base_strength("BRA")
      assert is_float(result)
      assert result != 1.0, "Expected BRA to have non-default base strength"
    end
  end

  describe "calculate_team_strength/2" do
    test "returns exactly 0.97 for two non-existent teams (all defaults)" do
      result = MatchSimulation.calculate_team_strength("NONEXISTENT1", "NONEXISTENT2")
      # form=1.0 (30%) + h2h=1.0 (20%) + wc=0.9 (30%) + base=1.0 (20%) = 0.97
      assert_in_delta result, 0.97, 0.001
    end

    test "returns different strength for real teams vs non-existent teams" do
      real_strength = MatchSimulation.calculate_team_strength("BRA", "ARG")
      default_strength = MatchSimulation.calculate_team_strength("NONEXISTENT1", "NONEXISTENT2")
      assert real_strength != default_strength, "Real team strength should differ from default"
    end

    test "result is clamped to valid range 0.5 to 1.5" do
      result = MatchSimulation.calculate_team_strength("NONEXISTENT1", "NONEXISTENT2")
      assert result >= 0.5
      assert result <= 1.5

      real_result = MatchSimulation.calculate_team_strength("BRA", "ARG")
      assert real_result >= 0.5
      assert real_result <= 1.5
    end
  end

  describe "get_strength_breakdown/2" do
    test "returns correct structure" do
      breakdown = MatchSimulation.get_strength_breakdown("NONEXISTENT1", "NONEXISTENT2")

      assert Map.has_key?(breakdown, :form)
      assert Map.has_key?(breakdown, :h2h)
      assert Map.has_key?(breakdown, :world_cup)
      assert Map.has_key?(breakdown, :base)
      assert Map.has_key?(breakdown, :overall)

      assert is_float(breakdown.form.value)
      assert is_float(breakdown.form.weight)
      assert is_float(breakdown.form.weighted)
      assert is_float(breakdown.overall)
    end

    test "returns real values for teams with historical data" do
      breakdown = MatchSimulation.get_strength_breakdown("BRA", "ARG")
      assert is_float(breakdown.overall)
      # BRA and ARG have real data, so breakdown values should be non-trivial
      assert breakdown.form.value != 1.0 or breakdown.h2h.value != 1.0
    end
  end

  describe "simulate_match/3" do
    test "returns valid simulation result structure" do
      result = MatchSimulation.simulate_match("NONEXISTENT1", "NONEXISTENT2")

      assert is_float(result.home_win_pct)
      assert is_float(result.draw_pct)
      assert is_float(result.away_win_pct)
      assert is_float(result.avg_home_goals)
      assert is_float(result.avg_away_goals)
      assert is_integer(result.simulations)
      assert is_list(result.most_likely_scores)
      assert is_map(result.score_distribution)
    end

    test "accepts custom simulation count" do
      result = MatchSimulation.simulate_match("NONEXISTENT1", "NONEXISTENT2", simulations: 50)
      assert result.simulations == 50
    end

    test "percentages sum to approximately 100" do
      result = MatchSimulation.simulate_match("NONEXISTENT1", "NONEXISTENT2", simulations: 100)
      total = result.home_win_pct + result.draw_pct + result.away_win_pct
      assert_in_delta total, 100.0, 0.5
    end

    test "returns non-negative average goals" do
      result = MatchSimulation.simulate_match("NONEXISTENT1", "NONEXISTENT2", simulations: 100)
      assert result.avg_home_goals >= 0
      assert result.avg_away_goals >= 0
    end

    test "simulation for real teams produces different results than default teams" do
      # BRA vs ARG have real historical data - results should differ from NONEXISTENT teams
      real_result = MatchSimulation.simulate_match("BRA", "ARG", simulations: 100)
      default_result = MatchSimulation.simulate_match("NONEXISTENT1", "NONEXISTENT2", simulations: 100)

      # Strengths should differ because real teams have data
      assert real_result.team1_strength != default_result.team1_strength
    end
  end
end

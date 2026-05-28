defmodule Jalka2026.Football.MatchSimulation do
  @moduledoc """
  Monte Carlo simulation engine for predicting match outcomes.

  Uses team statistics, historical data, and recent form to calculate
  team strengths and simulate match outcomes with probability distributions.
  """

  alias Jalka2026.Football

  @default_simulations 10_000
  # Average goals per team in international football
  @base_goals_per_match 2.6
  # 10% home advantage factor
  @home_advantage 0.1
  # Weight of recent form in strength calculation
  @form_weight 0.3
  # Weight of head-to-head history
  @h2h_weight 0.2
  # Weight of World Cup performance
  @wc_weight 0.3
  # Weight of base team strength
  @base_weight 0.2

  @doc """
  Run a Monte Carlo simulation for a match between two teams.

  Returns a map with:
  - :simulations - number of simulations run
  - :home_win_pct - percentage of home wins
  - :draw_pct - percentage of draws
  - :away_win_pct - percentage of away wins
  - :score_distribution - map of {home_score, away_score} => count
  - :most_likely_scores - top 5 most likely scores
  - :avg_home_goals - average home team goals
  - :avg_away_goals - average away team goals
  - :team1_strength - calculated strength for team 1
  - :team2_strength - calculated strength for team 2
  """
  def simulate_match(team1_code, team2_code, opts \\ []) do
    num_simulations = Keyword.get(opts, :simulations, @default_simulations)

    # Calculate team strengths
    team1_strength = calculate_team_strength(team1_code, team2_code)
    team2_strength = calculate_team_strength(team2_code, team1_code)

    # Apply home advantage to team1
    team1_lambda = calculate_expected_goals(team1_strength, team2_strength, true)
    team2_lambda = calculate_expected_goals(team2_strength, team1_strength, false)

    # Run simulations
    results = run_simulations(num_simulations, team1_lambda, team2_lambda)

    # Aggregate results
    aggregate_results(results, num_simulations, team1_strength, team2_strength)
  end

  @doc """
  Calculate team strength based on multiple factors:
  - Recent form
  - Head-to-head history with opponent
  - World Cup performance history
  - Base team strength estimation
  """
  def calculate_team_strength(team_code, opponent_code) do
    form_strength = calculate_form_strength(team_code)
    h2h_strength = calculate_h2h_strength(team_code, opponent_code)
    wc_strength = calculate_wc_strength(team_code)
    base_strength = calculate_base_strength(team_code)

    # Weighted combination of all factors
    strength =
      @form_weight * form_strength +
        @h2h_weight * h2h_strength +
        @wc_weight * wc_strength +
        @base_weight * base_strength

    # Normalize to reasonable range (0.5 to 1.5)
    max(0.5, min(1.5, strength))
  end

  @doc """
  Calculate strength based on recent form (last 5-10 matches).
  """
  def calculate_form_strength(team_code) do
    form = Football.get_team_recent_form(team_code, 10)

    if Enum.empty?(form) do
      # Default neutral strength
      1.0
    else
      # Calculate points per game (3 for win, 1 for draw, 0 for loss)
      total_points =
        Enum.reduce(form, 0, fn match, acc ->
          acc + result_points(match.result)
        end)

      # Calculate goal difference per game
      {goals_for, goals_against} =
        Enum.reduce(form, {0, 0}, fn match, {gf, ga} ->
          {gf + match.goals_for, ga + match.goals_against}
        end)

      matches = length(form)
      # Normalized to 0-1
      ppg = total_points / (matches * 3)
      gd_per_match = (goals_for - goals_against) / matches

      # Combine PPG and goal difference
      # PPG gives base strength (0.6 - 1.4)
      # Goal difference adds adjustment
      0.6 + ppg * 0.8 + gd_per_match * 0.05
    end
  end

  @doc """
  Calculate strength based on head-to-head history with opponent.
  """
  def calculate_h2h_strength(team_code, opponent_code) do
    stats = Football.get_historical_stats(team_code, opponent_code)

    if stats.total_matches == 0 do
      # No history, neutral
      1.0
    else
      # Win rate against this opponent
      win_rate = stats.team1_wins / stats.total_matches
      draw_rate = stats.draws / stats.total_matches

      # Goal difference per match
      gd_per_match = (stats.team1_goals - stats.team2_goals) / stats.total_matches

      # Combine win rate (with draws counting as 0.5) and goal difference
      effective_win_rate = win_rate + draw_rate * 0.5

      # Scale to 0.6 - 1.4 range
      0.6 + effective_win_rate * 0.6 + gd_per_match * 0.04
    end
  end

  @doc """
  Calculate strength based on World Cup history.
  """
  def calculate_wc_strength(team_code) do
    stats = Football.get_team_world_cup_stats(team_code)

    if stats.matches_played == 0 do
      # Teams without WC history get slight penalty
      0.9
    else
      # Points per game in World Cups
      points = stats.wins * 3 + stats.draws
      ppg = points / (stats.matches_played * 3)

      # Goal difference per match
      gd_per_match = (stats.goals_for - stats.goals_against) / stats.matches_played

      # Experience bonus (more matches = more experienced)
      experience_bonus = min(0.1, stats.matches_played * 0.002)

      # Scale to 0.6 - 1.5 range with experience
      0.6 + ppg * 0.7 + gd_per_match * 0.03 + experience_bonus
    end
  end

  @doc """
  Calculate base team strength from overall historical performance.
  """
  def calculate_base_strength(team_code) do
    # Use all recent matches to get base form
    form = Football.get_team_recent_form(team_code, 20)

    if Enum.empty?(form) do
      1.0
    else
      # Calculate average goals scored and conceded
      {goals_for, goals_against} =
        Enum.reduce(form, {0, 0}, fn match, {gf, ga} ->
          {gf + match.goals_for, ga + match.goals_against}
        end)

      matches = length(form)
      avg_gf = goals_for / matches
      avg_ga = goals_against / matches

      # Offensive and defensive ratings
      offensive_rating = avg_gf / @base_goals_per_match
      defensive_rating = @base_goals_per_match / max(avg_ga, 0.5)

      # Combine offensive and defensive
      (offensive_rating + defensive_rating) / 2
    end
  end

  @doc """
  Calculate expected goals (lambda for Poisson distribution).
  """
  def calculate_expected_goals(team_strength, opponent_strength, is_home) do
    # Base expected goals modified by relative strength
    relative_strength = team_strength / opponent_strength

    # Apply home advantage
    home_factor = if is_home, do: 1 + @home_advantage, else: 1 - @home_advantage

    # Expected goals = base * relative_strength * home_factor
    @base_goals_per_match * relative_strength * home_factor / 2
  end

  @doc """
  Run the Monte Carlo simulations.
  """
  def run_simulations(num_simulations, team1_lambda, team2_lambda) do
    Enum.map(1..num_simulations, fn _ ->
      home_goals = poisson_random(team1_lambda)
      away_goals = poisson_random(team2_lambda)
      {home_goals, away_goals}
    end)
  end

  @doc """
  Generate a Poisson-distributed random number.
  Uses the inverse transform method.
  """
  def poisson_random(lambda) when lambda <= 0, do: 0

  def poisson_random(lambda) do
    l = :math.exp(-lambda)
    poisson_random_loop(l, 1.0, 0)
  end

  defp result_points("W"), do: 3
  defp result_points("D"), do: 1
  defp result_points("L"), do: 0

  defp poisson_random_loop(l, p, k) when p > l do
    u = :rand.uniform()
    poisson_random_loop(l, p * u, k + 1)
  end

  defp poisson_random_loop(_l, _p, k), do: k

  @doc """
  Aggregate simulation results into summary statistics.
  """
  def aggregate_results(results, num_simulations, team1_strength, team2_strength) do
    # Count outcomes
    {home_wins, draws, away_wins} =
      Enum.reduce(results, {0, 0, 0}, fn {home, away}, {hw, d, aw} ->
        cond do
          home > away -> {hw + 1, d, aw}
          home == away -> {hw, d + 1, aw}
          true -> {hw, d, aw + 1}
        end
      end)

    # Score distribution
    score_counts = Enum.frequencies(results)

    # Calculate averages
    {total_home, total_away} =
      Enum.reduce(results, {0, 0}, fn {home, away}, {th, ta} ->
        {th + home, ta + away}
      end)

    # Get most likely scores
    most_likely =
      score_counts
      |> Enum.sort_by(fn {_score, count} -> count end, :desc)
      |> Enum.take(10)
      |> Enum.map(fn {{home, away}, count} ->
        %{
          home_score: home,
          away_score: away,
          count: count,
          percentage: Float.round(count / num_simulations * 100, 1)
        }
      end)

    # Generate probability matrix for visualization (0-5 goals each)
    score_matrix = generate_score_matrix(score_counts, num_simulations)

    %{
      simulations: num_simulations,
      home_win_pct: Float.round(home_wins / num_simulations * 100, 1),
      draw_pct: Float.round(draws / num_simulations * 100, 1),
      away_win_pct: Float.round(away_wins / num_simulations * 100, 1),
      score_distribution: score_counts,
      most_likely_scores: most_likely,
      score_matrix: score_matrix,
      avg_home_goals: Float.round(total_home / num_simulations, 2),
      avg_away_goals: Float.round(total_away / num_simulations, 2),
      team1_strength: Float.round(team1_strength, 3),
      team2_strength: Float.round(team2_strength, 3)
    }
  end

  @doc """
  Generate a 6x6 matrix of score probabilities (0-5 goals each team).
  """
  def generate_score_matrix(score_counts, num_simulations) do
    for home <- 0..5 do
      for away <- 0..5 do
        count = Map.get(score_counts, {home, away}, 0)

        %{
          home_goals: home,
          away_goals: away,
          count: count,
          percentage: Float.round(count / num_simulations * 100, 1)
        }
      end
    end
  end

  @doc """
  Get detailed strength breakdown for a team.
  Useful for displaying how the simulation calculated team strength.
  """
  def get_strength_breakdown(team_code, opponent_code) do
    form_strength = calculate_form_strength(team_code)
    h2h_strength = calculate_h2h_strength(team_code, opponent_code)
    wc_strength = calculate_wc_strength(team_code)
    base_strength = calculate_base_strength(team_code)

    overall =
      @form_weight * form_strength +
        @h2h_weight * h2h_strength +
        @wc_weight * wc_strength +
        @base_weight * base_strength

    %{
      form: %{
        value: Float.round(form_strength, 3),
        weight: @form_weight,
        weighted: Float.round(@form_weight * form_strength, 3)
      },
      h2h: %{
        value: Float.round(h2h_strength, 3),
        weight: @h2h_weight,
        weighted: Float.round(@h2h_weight * h2h_strength, 3)
      },
      world_cup: %{
        value: Float.round(wc_strength, 3),
        weight: @wc_weight,
        weighted: Float.round(@wc_weight * wc_strength, 3)
      },
      base: %{
        value: Float.round(base_strength, 3),
        weight: @base_weight,
        weighted: Float.round(@base_weight * base_strength, 3)
      },
      overall: Float.round(max(0.5, min(1.5, overall)), 3)
    }
  end
end

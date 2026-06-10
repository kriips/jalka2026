defmodule Jalka2026.Scoring do
  @moduledoc """
  Pure scoring functions for the prediction game.

  All functions are side-effect-free and operate on plain data,
  making them trivially unit-testable without database or process state.

  ## Group match scoring
  - Correct result (right outcome, wrong score): 1 point
  - Exact score (right outcome AND right score): 2 points
  - Wrong result: 0 points

  ## Playoff scoring (per correct team prediction)
  - Round of 32: 1 point
  - Round of 16: 2 points
  - Quarter-finals (8): 3 points
  - Semi-finals (4): 5 points
  - Final (2): 6 points
  """

  @type match_like :: %{result: String.t(), home_score: integer(), away_score: integer()}
  @type prediction_like ::
          %{result: String.t(), home_score: integer(), away_score: integer()} | nil
  @type team_ids :: Enumerable.t()

  # --- Named constants (single source of truth) ---
  @group_exact_score_points 2
  @group_correct_result_points 1
  @group_wrong_points 0

  # Stored PlayoffPrediction phases are the WINNER picks of each bracket round, so the team
  # at a phase actually *reached the next stage*. Points are therefore offset by one stage from
  # the phase number: phase 32 = reached last-16 (2pt) ... phase 2 = the tournament winner (8pt).
  # The "reached last-32" stage (1pt) is NOT a stored phase — it is scored separately from the
  # user's predicted group qualifiers (see Jalka2026.Football.Qualifiers / last_32_points/2).
  @playoff_points %{32 => 2, 16 => 3, 8 => 5, 4 => 6, 2 => 8}

  # Points per correctly-predicted team that reaches the round of 32 (the "32 parimat" stage).
  @reach_last_32_points 1

  @doc """
  Calculate points for a single group match prediction.

  Returns 2 for exact score, 1 for correct result, 0 for wrong/missing prediction.

  ## Examples

      iex> match = %{result: "home", home_score: 2, away_score: 1}
      iex> Jalka2026.Scoring.group_match_points(match, %{result: "home", home_score: 2, away_score: 1})
      2
      iex> Jalka2026.Scoring.group_match_points(match, %{result: "home", home_score: 3, away_score: 0})
      1
      iex> Jalka2026.Scoring.group_match_points(match, %{result: "away", home_score: 0, away_score: 2})
      0
  """
  def group_match_points(_match, nil), do: @group_wrong_points

  def group_match_points(match, prediction) do
    if match.result == prediction.result do
      if match.home_score == prediction.home_score &&
           match.away_score == prediction.away_score do
        @group_exact_score_points
      else
        @group_correct_result_points
      end
    else
      @group_wrong_points
    end
  end

  @doc """
  Calculate total group points for a user across all finished matches.

  `finished_matches` is a list of match structs/maps with `:id`, `:result`, `:home_score`, `:away_score`.
  `predictions_index` is a map of `{user_id, match_id} => prediction` or `match_id => prediction`.
  `user_id` is used to look up predictions in the index.

  Returns an integer total.
  """
  def total_group_points(finished_matches, predictions_index, user_id) do
    Enum.reduce(finished_matches, 0, fn match, acc ->
      prediction = Map.get(predictions_index, {user_id, match.id})
      acc + group_match_points(match, prediction)
    end)
  end

  @doc """
  Points awarded for a correct playoff prediction at a given phase.

  ## Examples

      iex> Jalka2026.Scoring.playoff_phase_points(32)
      2
      iex> Jalka2026.Scoring.playoff_phase_points(2)
      8
  """
  for {phase, points} <- @playoff_points do
    def playoff_phase_points(unquote(phase)), do: unquote(points)
  end

  @doc """
  Points awarded per correctly-predicted "reached last-32" team (the "32 parimat" stage).
  """
  @spec reach_last_32_points() :: pos_integer()
  def reach_last_32_points, do: @reach_last_32_points

  @doc """
  Total points for the "32 parimat" stage: `@reach_last_32_points` for each team that the user
  predicted to reach the round of 32 (their group qualifiers, with R32 swap-overrides applied)
  AND that actually reached it.

  Both arguments are enumerables of team ids. Returns an integer.
  """
  @spec last_32_points(team_ids(), team_ids()) :: non_neg_integer()
  def last_32_points(predicted_team_ids, actual_team_ids) do
    actual = MapSet.new(actual_team_ids)

    predicted_team_ids
    |> MapSet.new()
    |> MapSet.intersection(actual)
    |> MapSet.size()
    |> Kernel.*(@reach_last_32_points)
  end

  @doc """
  Calculate total playoff points for a user.

  `playoff_results` is a list of structs/maps with `:team_id` and `:phase`.
  `user_playoff_predictions` is a map of `phase => [team_id, ...]` for the user.

  Returns an integer total.
  """
  def total_playoff_points(playoff_results, user_playoff_predictions) do
    empty_phases = Map.new(@playoff_points, fn {phase, _} -> {phase, []} end)
    predictions = Map.merge(empty_phases, user_playoff_predictions || %{})

    Enum.reduce(playoff_results, 0, fn result, acc ->
      if result.team_id in Map.get(predictions, result.phase, []) do
        acc + playoff_phase_points(result.phase)
      else
        acc
      end
    end)
  end

  @doc """
  Determine match result from home and away scores.

  Returns `"home"`, `"away"`, or `"draw"`.

  ## Examples

      iex> Jalka2026.Scoring.calculate_result(2, 1)
      "home"
      iex> Jalka2026.Scoring.calculate_result(1, 2)
      "away"
      iex> Jalka2026.Scoring.calculate_result(1, 1)
      "draw"
  """
  def calculate_result(home_score, away_score) do
    cond do
      home_score > away_score -> "home"
      home_score < away_score -> "away"
      home_score == away_score -> "draw"
    end
  end

  @doc """
  Returns the playoff phase → points map.

  Useful for consumers that need the full map instead of per-phase lookups.

  ## Example

      iex> Jalka2026.Scoring.playoff_phase_points_map()
      %{32 => 2, 16 => 3, 8 => 5, 4 => 6, 2 => 8}
  """
  def playoff_phase_points_map, do: @playoff_points

  @doc """
  Returns playoff phases in descending order (most teams → fewest).
  """
  def phases, do: [32, 16, 8, 4, 2]

  @doc """
  Unified scoring entry point.

  ## Group match

      Scoring.calculate(:group, {match, prediction})
      #=> 0 | 1 | 2

  ## Playoff phase

      Scoring.calculate(:playoff, phase)
      #=> points for that phase
  """
  def calculate(:group, {match, prediction}), do: group_match_points(match, prediction)
  def calculate(:playoff, phase), do: playoff_phase_points(phase)

  @doc """
  Check if a prediction result matches the actual match result.

  Returns `true` if the prediction result equals the match result, `false` otherwise.
  Returns `false` for nil predictions.
  """
  def prediction_correct?(_match, nil), do: false
  def prediction_correct?(match, prediction), do: match.result == prediction.result

  @doc """
  Calculate streak statistics from an ordered list of finished matches and a predictions map.

  Returns `{current_streak, longest_streak}`.

  `finished_matches` must be ordered chronologically.
  `predictions` is a map of `match_id => prediction`.
  """
  def calculate_streak_stats(finished_matches, predictions) do
    {_current, longest, final_current} =
      Enum.reduce(finished_matches, {0, 0, 0}, fn match, {current, longest, _} ->
        prediction = Map.get(predictions, match.id)

        if prediction_correct?(match, prediction) do
          new_current = current + 1
          new_longest = max(new_current, longest)
          {new_current, new_longest, new_current}
        else
          {0, longest, 0}
        end
      end)

    {final_current, longest}
  end
end

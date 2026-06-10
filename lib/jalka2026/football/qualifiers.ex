defmodule Jalka2026.Football.Qualifiers do
  @moduledoc """
  Computes the set of teams that reach the round of 32 — the "32 parimat" scoring stage.

  This stage is intentionally NOT backed by `PlayoffPrediction` rows (the bracket only stores
  the winner picks of each round). Instead it is derived on the fly so the stored data structure
  stays untouched:

    * `predicted_last_32/1` — a user's predicted round-of-32 teams: their predicted group
      qualifiers (top 2 of every group + the 8 best third-placed teams), WITH that user's
      round-of-32 swap-overrides applied. This is why last-32 bracket swaps now affect scoring.
    * `all_predicted_last_32/0` — the same, for ALL users at once, bulk-loaded (a constant handful
      of queries instead of ~85 per user). Used by the leaderboard recalc and the playoff overview.
    * `actual_last_32/0` — the teams that actually reached the round of 32, derived from the
      finished group results (empty until the group stage is complete).

  All return unique lists of team ids; `Jalka2026.Scoring.last_32_points/2` scores the overlap.
  """

  alias Jalka2026.Football
  alias Jalka2026.Football.BracketSeeding
  alias Jalka2026.Football.GroupScenarios

  @groups ~w(A B C D E F G H I J K L)

  @type team_id :: term()
  @type team_ids :: [team_id()]
  @type user_id :: pos_integer()

  @doc """
  List of team ids the user predicts to reach the round of 32 — their predicted group
  qualifiers with round-of-32 swap-overrides applied. Empty until all 12 groups are predicted.
  """
  @spec predicted_last_32(user_id()) :: team_ids()
  def predicted_last_32(user_id) do
    standings = GroupScenarios.get_all_predicted_standings(user_id)
    overrides = Map.get(Football.get_bracket_overrides_by_round(user_id), "round_of_32", [])
    version = Football.get_playoff_bracket_version(user_id)

    last_32_from_standings(standings, overrides, version)
  end

  @doc """
  `%{user_id => [team_id]}` of predicted round-of-32 teams for ALL users, bulk-loaded:
  one query for group matches, one for all group predictions, one for all overrides — then computed
  in memory. Equivalent to calling `predicted_last_32/1` per user, without the per-user N+1.
  """
  @spec all_predicted_last_32() :: %{optional(user_id()) => team_ids()}
  def all_predicted_last_32 do
    matches_by_group = Football.get_group_matches_grouped()
    overrides_by_user = Football.all_bracket_overrides_by_round()
    bracket_versions_by_user = Football.get_all_playoff_bracket_versions()

    Football.get_all_predictions_by_user()
    |> Map.new(fn {user_id, preds_by_match} ->
      standings = bulk_standings(matches_by_group, preds_by_match)
      overrides = Map.get(overrides_by_user, user_id, %{}) |> Map.get("round_of_32", [])
      version = Map.get(bracket_versions_by_user, user_id, BracketSeeding.official_version())

      {user_id, last_32_from_standings(standings, overrides, version)}
    end)
  end

  @doc """
  List of team ids that actually reached the round of 32, from finished group results.
  Empty until the group stage is complete (last-32 is only determined once groups end).
  """
  @spec actual_last_32() :: team_ids()
  def actual_last_32 do
    if group_stage_complete?() do
      standings = Map.new(@groups, fn g -> {g, GroupScenarios.get_group_standings(g)} end)
      third_groups = best_third_groups(standings)

      standings
      |> standings_team_map()
      |> BracketSeeding.resolve_r32_matchups(third_groups)
      |> Enum.flat_map(fn {_pos, home, away} -> [home, away] end)
      |> unique_team_ids()
    else
      []
    end
  end

  # Derive the round-of-32 team-id set from a per-group standings map (keyed by group letter) and a
  # user's round_of_32 matchup overrides. Shared by predicted_last_32/1 and all_predicted_last_32/0
  # so the two paths can never diverge. Empty unless all 12 groups are present (bracket unresolvable).
  @spec last_32_from_standings(map(), list(), String.t()) :: team_ids()
  defp last_32_from_standings(standings, round_of_32_overrides, bracket_version) do
    if map_size(standings) == length(@groups) do
      third_groups = best_third_groups(standings)
      ov = Map.new(round_of_32_overrides, fn o -> {{o.position, o.side}, o.team} end)

      standings
      |> standings_team_map()
      |> BracketSeeding.resolve_r32_matchups(third_groups, bracket_version)
      |> Enum.flat_map(fn {pos, home, away} ->
        [Map.get(ov, {pos, "a"}) || home, Map.get(ov, {pos, "b"}) || away]
      end)
      |> unique_team_ids()
    else
      []
    end
  end

  # Per-group predicted standings (keyed by group letter) computed in memory from pre-loaded matches
  # and a user's predictions (%{match_id => group_prediction}). A group is included only when all its
  # matches are predicted, matching GroupScenarios.get_all_predicted_standings/1.
  defp bulk_standings(matches_by_group, preds_by_match) do
    Enum.reduce(@groups, %{}, fn letter, acc ->
      put_bulk_standing(acc, letter, matches_by_group, preds_by_match)
    end)
  end

  defp put_bulk_standing(acc, letter, matches_by_group, preds_by_match) do
    matches = Map.get(matches_by_group, "Alagrupp #{letter}", [])
    group_preds = Enum.map(matches, fn m -> match_tuple(m, Map.get(preds_by_match, m.id)) end)

    if complete_group_predictions?(matches, group_preds) do
      Map.put(acc, letter, GroupScenarios.calculate_predicted_standings(group_preds))
    else
      acc
    end
  end

  defp complete_group_predictions?(matches, group_preds) do
    matches != [] and Enum.all?(group_preds, fn {_m, {h, a}} -> h != "-" and a != "-" end)
  end

  defp match_tuple(match, %{home_score: home_score, away_score: away_score}),
    do: {match, {home_score, away_score}}

  defp match_tuple(match, _no_prediction), do: {match, {"-", "-"}}

  defp standings_team_map(standings) do
    Map.new(standings, fn {group, ranked} -> {group, Enum.map(ranked, & &1.team)} end)
  end

  @spec unique_team_ids(Enumerable.t()) :: team_ids()
  defp unique_team_ids(teams) do
    teams
    |> Enum.reject(&is_nil/1)
    |> Enum.map(& &1.id)
    |> MapSet.new()
    |> MapSet.to_list()
  end

  # The 8 best third-placed groups from a standings map (same tiebreakers for predicted and actual).
  defp best_third_groups(standings) do
    standings
    |> Enum.map(fn {group, ranked} ->
      case Enum.at(ranked, 2) do
        nil ->
          nil

        third ->
          %{group: group, points: third.points, gd: third.goal_difference, gf: third.goals_for}
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort(fn a, b ->
      cond do
        a.points != b.points -> a.points > b.points
        a.gd != b.gd -> a.gd > b.gd
        a.gf != b.gf -> a.gf > b.gf
        true -> a.group <= b.group
      end
    end)
    |> Enum.take(8)
    |> Enum.map(& &1.group)
    |> Enum.sort()
  end

  defp group_stage_complete? do
    Enum.all?(@groups, fn g -> GroupScenarios.get_remaining_matches(g) == [] end)
  end
end

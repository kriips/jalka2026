defmodule Jalka2026.Football.GroupScenarios do
  @moduledoc """
  Calculates and displays all possible advancement scenarios for each group
  based on remaining fixtures. Shows what each team needs to advance.
  """

  alias Jalka2026.Repo
  import Ecto.Query

  # Local copy for use in guard clauses; derived from canonical source
  @valid_groups Jalka2026.Football.groups()

  @doc """
  Returns list of valid group letters.
  Delegates to `Jalka2026.Football.groups/0`.
  """
  def valid_groups, do: @valid_groups

  @doc """
  Gets the current standings for a group based on finished matches.
  Returns a list of team standings sorted by points, goal difference, and goals scored.
  """
  def get_group_standings(group) when group in @valid_groups do
    group_name = "Alagrupp #{group}"
    matches = get_group_matches(group_name)
    teams = get_group_teams(group)

    standings =
      teams
      |> Enum.map(fn team ->
        calculate_team_stats(team, matches)
      end)
      |> sort_standings()

    standings
  end

  @doc """
  Gets remaining (unfinished) matches for a group.
  """
  def get_remaining_matches(group) when group in @valid_groups do
    group_name = "Alagrupp #{group}"

    query =
      from(m in Jalka2026.Football.Match,
        where: m.group == ^group_name and m.finished == false,
        order_by: m.date,
        preload: [:home_team, :away_team]
      )

    Repo.all(query)
  end

  @doc """
  Gets finished matches for a group.
  """
  def get_finished_matches(group) when group in @valid_groups do
    group_name = "Alagrupp #{group}"

    query =
      from(m in Jalka2026.Football.Match,
        where: m.group == ^group_name and m.finished == true,
        order_by: m.date,
        preload: [:home_team, :away_team]
      )

    Repo.all(query)
  end

  @doc """
  Calculates all possible scenarios for a group based on remaining matches.
  Returns scenarios with advancement implications for each team.
  """
  def calculate_scenarios(group) when group in @valid_groups do
    remaining_matches = get_remaining_matches(group)
    current_standings = get_group_standings(group)

    if Enum.empty?(remaining_matches) do
      # No remaining matches, current standings are final
      %{
        status: :completed,
        final_standings: current_standings,
        scenarios: [],
        advancement: determine_advancement(current_standings)
      }
    else
      # Generate all possible outcomes for remaining matches
      all_scenarios = generate_all_scenarios(remaining_matches, current_standings)

      %{
        status: :in_progress,
        current_standings: current_standings,
        remaining_matches: remaining_matches,
        scenarios: all_scenarios,
        team_requirements: calculate_team_requirements(current_standings, all_scenarios)
      }
    end
  end

  @doc """
  Analyzes what each team needs to advance (top 2 positions).
  """
  def analyze_team_requirements(group) when group in @valid_groups do
    scenario_data = calculate_scenarios(group)

    case scenario_data.status do
      :completed ->
        advancement = scenario_data.advancement

        Enum.map(scenario_data.final_standings, fn team_stats ->
          %{
            team: team_stats.team,
            status: get_advancement_status(team_stats.team.id, advancement),
            message: get_final_message(team_stats.team.id, advancement)
          }
        end)

      :in_progress ->
        scenario_data.team_requirements
    end
  end

  # Private functions

  defp get_group_matches(group_name) do
    query =
      from(m in Jalka2026.Football.Match,
        where: m.group == ^group_name,
        preload: [:home_team, :away_team]
      )

    Repo.all(query)
  end

  defp get_group_teams(group) do
    Jalka2026.Football.Cache.get_teams()
    |> Enum.filter(&(&1.group == group))
    |> Enum.sort_by(& &1.name)
  end

  defp calculate_team_stats(team, matches) do
    team_matches =
      Enum.filter(matches, fn match ->
        match.finished && (match.home_team_id == team.id || match.away_team_id == team.id)
      end)

    {played, won, drawn, lost, goals_for, goals_against} =
      Enum.reduce(team_matches, {0, 0, 0, 0, 0, 0}, fn match, {p, w, d, l, gf, ga} ->
        is_home = match.home_team_id == team.id

        {scored, conceded} =
          if is_home do
            {match.home_score, match.away_score}
          else
            {match.away_score, match.home_score}
          end

        cond do
          scored > conceded -> {p + 1, w + 1, d, l, gf + scored, ga + conceded}
          scored < conceded -> {p + 1, w, d, l + 1, gf + scored, ga + conceded}
          true -> {p + 1, w, d + 1, l, gf + scored, ga + conceded}
        end
      end)

    points = won * 3 + drawn
    goal_difference = goals_for - goals_against

    %{
      team: team,
      played: played,
      won: won,
      drawn: drawn,
      lost: lost,
      goals_for: goals_for,
      goals_against: goals_against,
      goal_difference: goal_difference,
      points: points
    }
  end

  defp sort_standings(standings) do
    Enum.sort(standings, fn a, b ->
      cond do
        a.points != b.points -> a.points > b.points
        a.goal_difference != b.goal_difference -> a.goal_difference > b.goal_difference
        a.goals_for != b.goals_for -> a.goals_for > b.goals_for
        true -> a.team.name <= b.team.name
      end
    end)
  end

  defp generate_all_scenarios(remaining_matches, current_standings) do
    outcomes = [:home_win, :draw, :away_win]

    # Generate all possible combinations of outcomes
    combinations = generate_outcome_combinations(length(remaining_matches), outcomes)

    Enum.map(combinations, fn outcome_list ->
      simulated_standings = simulate_scenario(remaining_matches, outcome_list, current_standings)
      sorted = sort_standings(simulated_standings)

      %{
        outcomes: Enum.zip(remaining_matches, outcome_list) |> Enum.into([]),
        standings: sorted,
        qualified: Enum.take(sorted, 2) |> Enum.map(& &1.team.id)
      }
    end)
  end

  defp generate_outcome_combinations(0, _outcomes), do: [[]]

  defp generate_outcome_combinations(n, outcomes) do
    for outcome <- outcomes,
        rest <- generate_outcome_combinations(n - 1, outcomes) do
      [outcome | rest]
    end
  end

  defp simulate_scenario(matches, outcomes, current_standings) do
    match_outcomes = Enum.zip(matches, outcomes)

    Enum.map(current_standings, fn team_stats ->
      additional_stats =
        Enum.reduce(match_outcomes, {0, 0, 0, 0, 0}, fn {match, outcome}, acc ->
          apply_match_outcome(match, outcome, team_stats.team.id, acc)
        end)

      {add_won, add_drawn, add_lost, add_gf, add_ga} = additional_stats

      %{
        team_stats
        | played: team_stats.played + add_won + add_drawn + add_lost,
          won: team_stats.won + add_won,
          drawn: team_stats.drawn + add_drawn,
          lost: team_stats.lost + add_lost,
          goals_for: team_stats.goals_for + add_gf,
          goals_against: team_stats.goals_against + add_ga,
          goal_difference: team_stats.goal_difference + add_gf - add_ga,
          points: team_stats.points + add_won * 3 + add_drawn
      }
    end)
  end

  defp apply_match_outcome(match, outcome, team_id, {w, d, l, gf, ga}) do
    cond do
      match.home_team_id == team_id -> apply_home_outcome(outcome, {w, d, l, gf, ga})
      match.away_team_id == team_id -> apply_away_outcome(outcome, {w, d, l, gf, ga})
      true -> {w, d, l, gf, ga}
    end
  end

  defp apply_home_outcome(:home_win, {w, d, l, gf, ga}), do: {w + 1, d, l, gf + 2, ga}
  defp apply_home_outcome(:draw, {w, d, l, gf, ga}), do: {w, d + 1, l, gf + 1, ga + 1}
  defp apply_home_outcome(:away_win, {w, d, l, gf, ga}), do: {w, d, l + 1, gf, ga + 2}

  defp apply_away_outcome(:home_win, {w, d, l, gf, ga}), do: {w, d, l + 1, gf, ga + 2}
  defp apply_away_outcome(:draw, {w, d, l, gf, ga}), do: {w, d + 1, l, gf + 1, ga + 1}
  defp apply_away_outcome(:away_win, {w, d, l, gf, ga}), do: {w + 1, d, l, gf + 2, ga}

  defp calculate_team_requirements(current_standings, scenarios) do
    Enum.map(current_standings, fn team_stats ->
      team_id = team_stats.team.id

      # Count scenarios where team qualifies
      qualifying_scenarios = Enum.filter(scenarios, fn s -> team_id in s.qualified end)
      total_scenarios = length(scenarios)
      qualifying_count = length(qualifying_scenarios)

      status =
        cond do
          qualifying_count == total_scenarios -> :qualified
          qualifying_count == 0 -> :eliminated
          qualifying_count >= total_scenarios * 0.75 -> :likely
          qualifying_count >= total_scenarios * 0.25 -> :possible
          true -> :unlikely
        end

      message =
        generate_requirement_message(team_stats, status, qualifying_count, total_scenarios)

      %{
        team: team_stats.team,
        current_stats: team_stats,
        status: status,
        qualifying_scenarios: qualifying_count,
        total_scenarios: total_scenarios,
        percentage: round(qualifying_count / total_scenarios * 100),
        message: message
      }
    end)
  end

  defp generate_requirement_message(_team_stats, status, qualifying_count, total_scenarios) do
    percentage = round(qualifying_count / total_scenarios * 100)

    case status do
      :qualified ->
        "Kindlalt edasi! Edasipääs on garanteeritud olenemata ülejäänud mängude tulemustest."

      :eliminated ->
        "Edasipääs pole enam võimalik."

      :likely ->
        "Väga hea positsioon. Edasipääs #{percentage}% stsenaariumites."

      :possible ->
        "Edasipääs on võimalik. Pääseb edasi #{percentage}% stsenaariumites."

      :unlikely ->
        "Edasipääs ebatõenäoline. Vaja on soodsaid tulemusi teistelt mängudelt."
    end
  end

  defp determine_advancement(final_standings) do
    qualified = Enum.take(final_standings, 2) |> Enum.map(& &1.team.id)
    eliminated = Enum.drop(final_standings, 2) |> Enum.map(& &1.team.id)

    %{
      qualified: qualified,
      eliminated: eliminated
    }
  end

  defp get_advancement_status(team_id, advancement) do
    cond do
      team_id in advancement.qualified -> :qualified
      team_id in advancement.eliminated -> :eliminated
      true -> :unknown
    end
  end

  defp get_final_message(team_id, advancement) do
    if team_id in advancement.qualified do
      "Kindlalt edasi! Koht playoff-mängudes tagatud."
    else
      "Alagrupiturniir lõppenud. Edasipääs jäi saavutamata."
    end
  end

  @doc """
  Calculate predicted group standings based on a user's predictions.
  Takes a list of {match, {home_score, away_score}} tuples (from the prediction page).
  Returns sorted standings showing what the group table would look like if predictions come true.
  """
  def calculate_predicted_standings(predictions) do
    # Extract teams from the matches
    teams =
      predictions
      |> Enum.flat_map(fn {match, _scores} -> [match.home_team, match.away_team] end)
      |> Enum.uniq_by(& &1.id)

    # Calculate stats for each team based on predictions
    standings =
      teams
      |> Enum.map(fn team ->
        calculate_predicted_team_stats(team, predictions)
      end)
      |> sort_standings()

    standings
  end

  @doc """
  Get the predicted top 2 teams (qualifiers) from a group based on user predictions.
  Returns a list of team IDs that would qualify.
  """
  def get_predicted_qualifiers(predictions) do
    standings = calculate_predicted_standings(predictions)
    standings |> Enum.take(2) |> Enum.map(& &1.team.id)
  end

  @doc """
  Get predicted qualifiers for all groups for a given user.
  Returns a list of team IDs that would qualify across all groups.
  """
  def get_all_predicted_qualifiers(user_id) do
    alias Jalka2026.Football

    @valid_groups
    |> Enum.flat_map(fn group ->
      group_name = "Alagrupp #{group}"
      matches = Football.get_matches_by_group(group_name)
      predictions = build_group_predictions(matches, user_id)

      # Only calculate if all predictions are filled
      all_filled = Enum.all?(predictions, fn {_m, {h, a}} -> h != "-" and a != "-" end)

      if all_filled do
        get_predicted_qualifiers(predictions)
      else
        []
      end
    end)
  end

  @doc """
  Returns predicted standings for ALL 12 groups based on a user's group predictions.
  Returns a map of %{"A" => [standing_1st, standing_2nd, standing_3rd, standing_4th], "B" => [...], ...}.
  Groups where predictions are not fully filled in are omitted from the result.
  """
  def get_all_predicted_standings(user_id) do
    alias Jalka2026.Football

    @valid_groups
    |> Enum.reduce(%{}, fn group, acc ->
      group_name = "Alagrupp #{group}"
      matches = Football.get_matches_by_group(group_name)
      predictions = build_group_predictions(matches, user_id)

      all_filled = Enum.all?(predictions, fn {_m, {h, a}} -> h != "-" and a != "-" end)

      if all_filled do
        standings = calculate_predicted_standings(predictions)
        Map.put(acc, group, standings)
      else
        acc
      end
    end)
  end

  @doc """
  Returns a list of third-place team standings across all 12 groups for a given user.
  Each entry is a map with :group, :team, :points, :goal_difference, :goals_for.
  Groups where predictions are not fully filled in are excluded.
  Sorted by points desc, goal_difference desc, goals_for desc.
  """
  def get_third_place_standings(user_id) do
    all_standings = get_all_predicted_standings(user_id)

    all_standings
    |> Enum.map(fn {group, standings} ->
      case Enum.at(standings, 2) do
        nil ->
          nil

        third_place ->
          %{
            group: group,
            team: third_place.team,
            points: third_place.points,
            goal_difference: third_place.goal_difference,
            goals_for: third_place.goals_for
          }
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort(fn a, b ->
      cond do
        a.points != b.points -> a.points > b.points
        a.goal_difference != b.goal_difference -> a.goal_difference > b.goal_difference
        a.goals_for != b.goals_for -> a.goals_for > b.goals_for
        true -> a.group <= b.group
      end
    end)
  end

  @doc """
  Returns a list of 8 group letters (strings) whose third-place teams are the best,
  based on the user's predicted standings. Sorted alphabetically.
  """
  def get_best_third_place_groups(user_id) do
    get_third_place_standings(user_id)
    |> Enum.take(8)
    |> Enum.map(& &1.group)
    |> Enum.sort()
  end

  defp build_group_predictions(matches, user_id) do
    alias Jalka2026.Football

    Enum.map(matches, fn match ->
      match_prediction_tuple(match, Football.get_prediction_by_user_match(user_id, match.id))
    end)
  end

  defp match_prediction_tuple(match, %{home_score: home_score, away_score: away_score}),
    do: {match, {home_score, away_score}}

  defp match_prediction_tuple(match, _no_prediction),
    do: {match, {"-", "-"}}

  defp calculate_predicted_team_stats(team, predictions) do
    # Only count predictions that are filled in (not "-")
    team_predictions =
      Enum.filter(predictions, fn {match, {home_score, away_score}} ->
        (match.home_team_id == team.id || match.away_team_id == team.id) &&
          home_score != "-" && away_score != "-"
      end)

    {played, won, drawn, lost, goals_for, goals_against} =
      Enum.reduce(team_predictions, {0, 0, 0, 0, 0, 0}, fn {match, {home_score, away_score}},
                                                           {p, w, d, l, gf, ga} ->
        is_home = match.home_team_id == team.id

        {scored, conceded} =
          if is_home do
            {home_score, away_score}
          else
            {away_score, home_score}
          end

        cond do
          scored > conceded -> {p + 1, w + 1, d, l, gf + scored, ga + conceded}
          scored < conceded -> {p + 1, w, d, l + 1, gf + scored, ga + conceded}
          true -> {p + 1, w, d + 1, l, gf + scored, ga + conceded}
        end
      end)

    points = won * 3 + drawn
    goal_difference = goals_for - goals_against

    %{
      team: team,
      played: played,
      won: won,
      drawn: drawn,
      lost: lost,
      goals_for: goals_for,
      goals_against: goals_against,
      goal_difference: goal_difference,
      points: points
    }
  end
end

defmodule Jalka2026Web.Resolvers.FootballResolver do
  @moduledoc false
  alias Jalka2026.Football
  alias Jalka2026.Football.TeamTranslations
  alias Jalka2026.Scoring

  def list_matches_by_group(group) do
    Football.get_matches_by_group("Alagrupp #{group}")
  end

  def list_matches() do
    Football.get_matches()
  end

  def list_finished_matches() do
    Football.get_finished_matches()
  end

  def list_playoff_results() do
    Football.get_playoff_results()
  end

  def list_match(id) do
    Football.get_match(id)
  end

  def update_match(%{
        "away_score" => away_score,
        "home_score" => home_score,
        "game_id" => game_id
      }) do
    match_id = String.to_integer(game_id)

    Football.enter_match_result(
      match_id,
      String.to_integer(home_score),
      String.to_integer(away_score)
    )
  end

  def update_playoff_result(%{"team_name" => team_name, "phase" => phase}) do
    Football.enter_playoff_result(team_name, phase)
  end

  def get_prediction(%{match_id: match_id, user_id: user_id}) do
    Football.get_prediction_by_user_match(user_id, match_id)
  end

  def get_predictions_by_match_result(match_id) do
    Football.get_predictions_by_match(match_id)
    |> group_by_result()
  end

  @doc """
  Calculates crowd confidence scores for a match.
  Returns a map with percentages for each outcome (home, draw, away)
  and the total number of predictions.

  ## Example
      %{
        home: 45.5,
        draw: 20.0,
        away: 34.5,
        total: 22,
        counts: %{home: 10, draw: 4, away: 8}
      }
  """
  def get_crowd_confidence(match_id) do
    predictions = Football.get_predictions_by_match(match_id)
    total = length(predictions)

    if total == 0 do
      %{
        home: 0.0,
        draw: 0.0,
        away: 0.0,
        total: 0,
        counts: %{home: 0, draw: 0, away: 0}
      }
    else
      grouped = Enum.group_by(predictions, & &1.result)

      home_count = length(grouped["home"] || [])
      draw_count = length(grouped["draw"] || [])
      away_count = length(grouped["away"] || [])

      %{
        home: Float.round(home_count / total * 100, 1),
        draw: Float.round(draw_count / total * 100, 1),
        away: Float.round(away_count / total * 100, 1),
        total: total,
        counts: %{home: home_count, draw: draw_count, away: away_count}
      }
    end
  end

  def get_predictions_by_user(user_id) do
    Football.get_predictions_by_user(user_id)
    |> Enum.sort(fn prediction1, prediction2 ->
      NaiveDateTime.compare(prediction1.match.date, prediction2.match.date) != :gt
    end)
  end

  def change_prediction_score(%{
        match_id: match_id,
        user_id: user_id,
        score: {home_score, away_score}
      }) do
    Football.change_score(%{
      user_id: user_id,
      match_id: match_id,
      home_score: home_score,
      away_score: away_score,
      result: calculate_result(home_score, away_score)
    })
  end

  def change_playoff_prediction(%{
        user_id: user_id,
        team_id: team_id,
        phase: phase,
        include: include
      }) do
    if include do
      Football.add_playoff_prediction(%{
        user_id: user_id,
        team_id: team_id,
        phase: phase
      })
    else
      Football.remove_playoff_prediction(%{
        user_id: user_id,
        team_id: team_id,
        phase: phase
      })
    end
  end

  def get_teams_by_group() do
    Jalka2026.Football.Cache.get_teams_by_group()
  end

  def filled_predictions(user_id) do
    user_predictions = Football.empty_match_group_map()

    Football.get_predictions_by_user(user_id)
    |> Enum.reduce(user_predictions, fn prediction, acc ->
      group = prediction.match.group
      Map.put(acc, group, acc[group] + 1)
    end)
  end

  def get_playoff_predictions(user_id) do
    user_playoff_predictions = %{
      32 => [],
      16 => [],
      8 => [],
      4 => [],
      2 => []
    }

    Football.get_playoff_predictions_by_user(user_id)
    |> Enum.reduce(user_playoff_predictions, fn prediction, acc ->
      Map.put(acc, prediction.phase, [prediction.team_id | acc[prediction.phase]])
    end)
  end

  def get_playoff_predictions_with_team_names(user_id) do
    user_playoff_predictions = %{
      32 => [],
      16 => [],
      8 => [],
      4 => [],
      2 => []
    }

    Football.get_playoff_predictions_by_user(user_id)
    |> Enum.reduce(user_playoff_predictions, fn prediction, acc ->
      translated_name = TeamTranslations.translate(prediction.team.name)
      Map.put(acc, prediction.phase, [translated_name | acc[prediction.phase]])
    end)
  end

  def get_playoff_predictions() do
    Football.get_playoff_predictions()
    |> group_by_phase()
    |> group_by_team()
    |> add_playoff_result()
    |> sort_by_count()
    |> sort_by_phase()
  end

  def get_predicted_qualifiers(user_id) do
    alias Jalka2026.Football.GroupScenarios
    GroupScenarios.get_all_predicted_qualifiers(user_id)
  end

  defdelegate calculate_result(home_score, away_score), to: Jalka2026.Scoring

  def add_correctness(user_predictions) do
    user_predictions
    |> Enum.map(fn user_prediction ->
      correct_result =
        if user_prediction.match.finished do
          user_prediction.result == user_prediction.match.result
        else
          false
        end

      correct_score =
        if correct_result do
          user_prediction.match.home_score == user_prediction.home_score &&
            user_prediction.match.away_score == user_prediction.away_score
        else
          false
        end

      {user_prediction, correct_result, correct_score}
    end)
  end

  def add_playoff_correctness(user_playoff_predictions) do
    user_playoff_predictions
    |> Enum.reduce(%{}, fn {phase, team_names}, acc ->
      modified_team_names = Enum.map(team_names, &highlight_if_reached(&1, phase))
      Map.put(acc, phase, modified_team_names)
    end)
  end

  defp highlight_if_reached(team_name, phase) do
    if team_name_reached_phase(team_name, phase) do
      "<b style=\"color:green\">" <> team_name <> "</b>"
    else
      team_name
    end
  end

  defp group_by_result(predictions) do
    predictions
    |> Enum.group_by(& &1.result, & &1)
  end

  defp group_by_phase(predictions) do
    playoff_predictions = %{
      2 => [],
      4 => [],
      8 => [],
      16 => [],
      32 => []
    }

    predictions
    |> Enum.reduce(playoff_predictions, fn prediction, acc ->
      translated_name = TeamTranslations.translate(prediction.team.name)

      Map.put(acc, prediction.phase, [
        %{team_name: translated_name, team_id: prediction.team.id, user_name: prediction.user.name}
        | acc[prediction.phase]
      ])
    end)
  end

  defp group_by_team(predictions) do
    predictions
    |> Enum.map(fn {phase, user_prediction} ->
      grouped =
        user_prediction
        |> Enum.group_by(fn p -> {p.team_name, p.team_id} end, & &1.user_name)
        |> Enum.map(fn {{team_name, team_id}, users} -> {team_name, team_id, users} end)

      {phase, grouped}
    end)
  end

  defp add_playoff_result(predictions) do
    predictions
    |> Enum.map(fn {phase, user_predictions} ->
      {phase, add_playoff_result_to_predictions(phase, user_predictions)}
    end)
  end

  defp add_playoff_result_to_predictions(phase, user_predictions) do
    Enum.map(user_predictions, fn {team_name, team_id, users} ->
      {team_name, team_reached_phase(team_id, phase), users}
    end)
  end

  defp team_reached_phase(team_id, phase) do
    Football.get_playoff_result_by_phase_team(phase, team_id) != nil
  end

  defp team_name_reached_phase(team_name, phase) do
    case Football.get_team_by_name(team_name) do
      [team | _] -> Football.get_playoff_result_by_phase_team(phase, team.id) != nil
      _ -> false
    end
  end

  defp sort_by_count(predictions) do
    predictions
    |> Enum.map(fn {phase, user_predictions} ->
      {
        phase,
        user_predictions
        |> Enum.sort(fn {_team_name1, _reached_phase1, users1},
                        {_team_name2, _reached_phase2, users2} ->
          Enum.count(users1) >= Enum.count(users2)
        end)
      }
    end)
  end

  defp sort_by_phase(predictions) do
    predictions
    |> Enum.sort(fn {phase1, _pred1}, {phase2, _pred2} ->
      phase1 >= phase2
    end)
  end

  @doc """
  Compares predictions between two users.
  Returns a map with group and playoff comparisons, as well as point summaries.
  """
  def compare_predictions(user1_id, user2_id) do
    user1_predictions = get_predictions_by_user(user1_id)
    user2_predictions = get_predictions_by_user(user2_id)

    user1_playoff = get_playoff_predictions_with_team_names(user1_id)
    user2_playoff = get_playoff_predictions_with_team_names(user2_id)

    user1_map = Map.new(user1_predictions, fn p -> {p.match_id, p} end)
    user2_map = Map.new(user2_predictions, fn p -> {p.match_id, p} end)

    all_match_ids =
      (Map.keys(user1_map) ++ Map.keys(user2_map))
      |> Enum.uniq()

    group_comparisons =
      all_match_ids
      |> Enum.map(fn match_id ->
        pred1 = Map.get(user1_map, match_id)
        pred2 = Map.get(user2_map, match_id)
        match = if pred1, do: pred1.match, else: pred2.match

        {points1, correct_result1, correct_score1} = calculate_prediction_points(pred1, match)
        {points2, correct_result2, correct_score2} = calculate_prediction_points(pred2, match)

        %{
          match: match,
          user1_prediction: format_prediction(pred1),
          user2_prediction: format_prediction(pred2),
          user1_points: points1,
          user2_points: points2,
          user1_correct_result: correct_result1,
          user1_correct_score: correct_score1,
          user2_correct_result: correct_result2,
          user2_correct_score: correct_score2,
          point_difference: points1 - points2
        }
      end)
      |> Enum.sort_by(fn c -> c.match.date end)

    playoff_comparisons = compare_playoff_predictions(user1_playoff, user2_playoff)

    %{
      group_comparisons: group_comparisons,
      playoff_comparisons: playoff_comparisons,
      summary: calculate_comparison_summary(group_comparisons, playoff_comparisons)
    }
  end

  defp format_prediction(nil), do: nil

  defp format_prediction(pred),
    do: %{home_score: pred.home_score, away_score: pred.away_score, result: pred.result}

  defp calculate_prediction_points(nil, _match), do: {0, false, false}
  defp calculate_prediction_points(_pred, %{finished: false}), do: {0, false, false}

  defp calculate_prediction_points(pred, match) do
    correct_result = pred.result == match.result

    correct_score =
      correct_result && pred.home_score == match.home_score && pred.away_score == match.away_score

    points =
      cond do
        correct_score -> 2
        correct_result -> 1
        true -> 0
      end

    {points, correct_result, correct_score}
  end

  defp compare_playoff_predictions(user1_playoff, user2_playoff) do
    phases = Scoring.phases()

    phase_names = %{
      32 => "32 parimat",
      16 => "Kaheksandikfinalistid",
      8 => "Veerandfinalistid",
      4 => "Poolfinalistid",
      2 => "Finalistid"
    }

    phase_points = Scoring.playoff_phase_points_map()

    Enum.map(phases, fn phase ->
      user1_teams = Map.get(user1_playoff, phase, [])
      user2_teams = Map.get(user2_playoff, phase, [])

      user1_teams_set = MapSet.new(user1_teams)
      user2_teams_set = MapSet.new(user2_teams)

      common_teams = MapSet.intersection(user1_teams_set, user2_teams_set) |> MapSet.to_list()
      only_user1 = MapSet.difference(user1_teams_set, user2_teams_set) |> MapSet.to_list()
      only_user2 = MapSet.difference(user2_teams_set, user1_teams_set) |> MapSet.to_list()

      # Calculate points for correct playoff predictions
      user1_points = calculate_playoff_phase_points(user1_teams, phase, phase_points)
      user2_points = calculate_playoff_phase_points(user2_teams, phase, phase_points)

      %{
        phase: phase,
        phase_name: phase_names[phase],
        phase_points: phase_points[phase],
        user1_teams: user1_teams,
        user2_teams: user2_teams,
        common_teams: common_teams,
        only_user1: only_user1,
        only_user2: only_user2,
        user1_points: user1_points,
        user2_points: user2_points
      }
    end)
  end

  defp calculate_playoff_phase_points(teams, phase, phase_points) do
    points_per_correct = phase_points[phase]

    Enum.reduce(teams, 0, fn team_name, acc ->
      if team_name_reached_phase(team_name, phase) do
        acc + points_per_correct
      else
        acc
      end
    end)
  end

  defp calculate_comparison_summary(group_comparisons, playoff_comparisons) do
    # Only count finished matches for group points
    finished_group_comparisons = Enum.filter(group_comparisons, fn c -> c.match.finished end)

    user1_group_points =
      Enum.reduce(finished_group_comparisons, 0, fn c, acc -> acc + c.user1_points end)

    user2_group_points =
      Enum.reduce(finished_group_comparisons, 0, fn c, acc -> acc + c.user2_points end)

    user1_playoff_points =
      Enum.reduce(playoff_comparisons, 0, fn c, acc -> acc + c.user1_points end)

    user2_playoff_points =
      Enum.reduce(playoff_comparisons, 0, fn c, acc -> acc + c.user2_points end)

    user1_correct_results =
      Enum.count(finished_group_comparisons, fn c -> c.user1_correct_result end)

    user2_correct_results =
      Enum.count(finished_group_comparisons, fn c -> c.user2_correct_result end)

    user1_correct_scores =
      Enum.count(finished_group_comparisons, fn c -> c.user1_correct_score end)

    user2_correct_scores =
      Enum.count(finished_group_comparisons, fn c -> c.user2_correct_score end)

    matches_user1_won =
      Enum.count(finished_group_comparisons, fn c -> c.user1_points > c.user2_points end)

    matches_user2_won =
      Enum.count(finished_group_comparisons, fn c -> c.user2_points > c.user1_points end)

    matches_tied =
      Enum.count(finished_group_comparisons, fn c -> c.user1_points == c.user2_points end)

    %{
      user1_group_points: user1_group_points,
      user2_group_points: user2_group_points,
      user1_playoff_points: user1_playoff_points,
      user2_playoff_points: user2_playoff_points,
      user1_total_points: user1_group_points + user1_playoff_points,
      user2_total_points: user2_group_points + user2_playoff_points,
      user1_correct_results: user1_correct_results,
      user2_correct_results: user2_correct_results,
      user1_correct_scores: user1_correct_scores,
      user2_correct_scores: user2_correct_scores,
      matches_user1_won: matches_user1_won,
      matches_user2_won: matches_user2_won,
      matches_tied: matches_tied,
      finished_matches_count: length(finished_group_comparisons),
      total_matches_count: length(group_comparisons)
    }
  end

  @doc """
  Calculates detailed prediction analytics for a user.
  Returns comprehensive statistics including accuracy percentages, best groups,
  best playoff phases, and trend data over time.
  """
  def get_prediction_analytics(user_id) do
    predictions = get_predictions_by_user(user_id)
    predictions_with_correctness = add_correctness(predictions)

    playoff_predictions = get_playoff_predictions_with_team_names(user_id)
    playoff_with_correctness = calculate_playoff_analytics(playoff_predictions)

    group_stats = calculate_group_stats(predictions_with_correctness)
    playoff_stats = calculate_playoff_stats(playoff_with_correctness)
    trend_data = calculate_trend_data(predictions_with_correctness)

    %{
      group_stats: group_stats,
      playoff_stats: playoff_stats,
      trend_data: trend_data,
      overall_stats: calculate_overall_stats(group_stats, playoff_stats)
    }
  end

  defp calculate_group_stats(predictions_with_correctness) do
    # Filter to only finished matches
    finished_predictions =
      Enum.filter(predictions_with_correctness, fn {pred, _, _} ->
        pred.match.finished
      end)

    total_finished = length(finished_predictions)

    if total_finished == 0 do
      %{
        total_predictions: 0,
        total_finished: 0,
        correct_results: 0,
        correct_scores: 0,
        result_accuracy: 0.0,
        score_accuracy: 0.0,
        points_earned: 0,
        max_possible_points: 0,
        by_group: %{},
        best_group: nil,
        worst_group: nil
      }
    else
      correct_results =
        Enum.count(finished_predictions, fn {_, correct_result, _} -> correct_result end)

      correct_scores =
        Enum.count(finished_predictions, fn {_, _, correct_score} -> correct_score end)

      points_earned = correct_results + correct_scores
      max_possible = total_finished * 2

      # Group by group name and calculate stats per group
      by_group =
        finished_predictions
        |> Enum.group_by(fn {pred, _, _} -> pred.match.group end)
        |> Enum.map(&calculate_single_group_stats/1)
        |> Map.new()

      # Find best and worst groups (minimum 3 matches to qualify)
      qualifying_groups = Enum.filter(by_group, fn {_, stats} -> stats.total >= 3 end)

      {best_group, worst_group} =
        if qualifying_groups != [] do
          sorted =
            Enum.sort_by(qualifying_groups, fn {_, stats} -> stats.result_accuracy end, :desc)

          {best, _} = hd(sorted)
          {worst, _} = List.last(sorted)
          {best, worst}
        else
          {nil, nil}
        end

      %{
        total_predictions: length(predictions_with_correctness),
        total_finished: total_finished,
        correct_results: correct_results,
        correct_scores: correct_scores,
        result_accuracy: Float.round(correct_results / total_finished * 100, 1),
        score_accuracy: Float.round(correct_scores / total_finished * 100, 1),
        points_earned: points_earned,
        max_possible_points: max_possible,
        by_group: by_group,
        best_group: best_group,
        worst_group: worst_group
      }
    end
  end

  defp calculate_single_group_stats({group, preds}) do
    group_total = length(preds)
    group_correct_results = Enum.count(preds, fn {_, cr, _} -> cr end)
    group_correct_scores = Enum.count(preds, fn {_, _, cs} -> cs end)
    group_points = group_correct_results + group_correct_scores

    accuracy =
      if group_total > 0, do: Float.round(group_correct_results / group_total * 100, 1), else: 0.0

    score_acc =
      if group_total > 0, do: Float.round(group_correct_scores / group_total * 100, 1), else: 0.0

    {group,
     %{
       total: group_total,
       correct_results: group_correct_results,
       correct_scores: group_correct_scores,
       points: group_points,
       result_accuracy: accuracy,
       score_accuracy: score_acc
     }}
  end

  defp calculate_playoff_analytics(playoff_predictions) do
    phases = Scoring.phases()
    phase_points_map = Scoring.playoff_phase_points_map()

    Enum.map(phases, fn phase ->
      teams = Map.get(playoff_predictions, phase, [])

      team_results =
        Enum.map(teams, fn team_name ->
          reached = team_reached_phase_for_analytics(team_name, phase)
          %{team_name: team_name, reached_phase: reached}
        end)

      correct_count = Enum.count(team_results, fn t -> t.reached_phase end)
      points_per_correct = phase_points_map[phase]

      %{
        phase: phase,
        teams: team_results,
        total_predictions: length(teams),
        correct_predictions: correct_count,
        points_earned: correct_count * points_per_correct,
        points_per_correct: points_per_correct,
        accuracy:
          if(teams != [], do: Float.round(correct_count / length(teams) * 100, 1), else: 0.0)
      }
    end)
  end

  defp team_reached_phase_for_analytics(team_name, phase) do
    case Football.get_team_by_name(team_name) do
      [team | _] -> Football.get_playoff_result_by_phase_team(phase, team.id) != nil
      [] -> false
    end
  end

  defp calculate_playoff_stats(playoff_analytics) do
    phase_names = %{
      32 => "32 parimat",
      16 => "Kaheksandikfinaalid",
      8 => "Veerandfinaalid",
      4 => "Poolfinaalid",
      2 => "Finaal"
    }

    total_predictions =
      Enum.reduce(playoff_analytics, 0, fn p, acc -> acc + p.total_predictions end)

    total_correct =
      Enum.reduce(playoff_analytics, 0, fn p, acc -> acc + p.correct_predictions end)

    total_points = Enum.reduce(playoff_analytics, 0, fn p, acc -> acc + p.points_earned end)

    by_phase =
      playoff_analytics
      |> Enum.map(fn p ->
        {phase_names[p.phase],
         %{
           phase: p.phase,
           total: p.total_predictions,
           correct: p.correct_predictions,
           points: p.points_earned,
           accuracy: p.accuracy
         }}
      end)
      |> Map.new()

    # Find best phase (with at least 1 prediction and some results)
    phases_with_predictions =
      Enum.filter(playoff_analytics, fn p ->
        p.total_predictions > 0 and
          (p.correct_predictions > 0 or has_playoff_results_for_phase(p.phase))
      end)

    best_phase =
      if phases_with_predictions != [] do
        best = Enum.max_by(phases_with_predictions, fn p -> p.accuracy end)
        phase_names[best.phase]
      else
        nil
      end

    %{
      total_predictions: total_predictions,
      total_correct: total_correct,
      total_points: total_points,
      overall_accuracy:
        if(total_predictions > 0,
          do: Float.round(total_correct / total_predictions * 100, 1),
          else: 0.0
        ),
      by_phase: by_phase,
      best_phase: best_phase,
      details: playoff_analytics
    }
  end

  defp has_playoff_results_for_phase(phase) do
    results = Football.get_playoff_results()
    Enum.any?(results, fn r -> r.phase == phase end)
  end

  defp calculate_trend_data(predictions_with_correctness) do
    # Sort predictions by date
    sorted =
      predictions_with_correctness
      |> Enum.filter(fn {pred, _, _} -> pred.match.finished end)
      |> Enum.sort_by(fn {pred, _, _} -> pred.match.date end)

    if sorted == [] do
      %{
        cumulative_accuracy: [],
        recent_form: [],
        streak_data: %{current: 0, longest_correct: 0, longest_incorrect: 0, type: nil}
      }
    else
      # Calculate cumulative accuracy over time
      {cumulative, _} = Enum.reduce(sorted, {[], {0, 0}}, &accumulate_trend_point/2)

      cumulative_data = Enum.reverse(cumulative)

      # Recent form (last 10 matches)
      recent = Enum.take(Enum.reverse(cumulative_data), -10)

      # Calculate streaks
      streak_data = calculate_streaks(sorted)

      %{
        cumulative_accuracy: cumulative_data,
        recent_form: recent,
        streak_data: streak_data
      }
    end
  end

  defp accumulate_trend_point({pred, correct_result, _}, {acc, {total_correct, total}}) do
    new_correct = if correct_result, do: total_correct + 1, else: total_correct
    new_total = total + 1
    accuracy = Float.round(new_correct / new_total * 100, 1)

    data_point = %{
      date: pred.match.date,
      match: "#{TeamTranslations.translate(pred.match.home_team.name)} vs #{TeamTranslations.translate(pred.match.away_team.name)}",
      accuracy: accuracy,
      correct: correct_result
    }

    {[data_point | acc], {new_correct, new_total}}
  end

  defp calculate_streaks(sorted_predictions) do
    results = Enum.map(sorted_predictions, fn {_, correct_result, _} -> correct_result end)

    if results == [] do
      %{current: 0, longest_correct: 0, longest_incorrect: 0, type: nil}
    else
      # Calculate current streak
      {current_streak, current_type} = calculate_current_streak(Enum.reverse(results))

      # Calculate longest streak
      longest_correct = calculate_longest_streak(results, true)
      longest_incorrect = calculate_longest_streak(results, false)

      %{
        current: current_streak,
        longest_correct: longest_correct,
        longest_incorrect: longest_incorrect,
        type: current_type
      }
    end
  end

  defp calculate_current_streak([]), do: {0, nil}

  defp calculate_current_streak([first | rest]) do
    count =
      1 +
        Enum.reduce_while(rest, 0, fn result, acc ->
          if result == first, do: {:cont, acc + 1}, else: {:halt, acc}
        end)

    type = if first, do: :correct, else: :incorrect
    {count, type}
  end

  defp calculate_longest_streak(results, target) do
    results
    |> Enum.chunk_by(& &1)
    |> Enum.filter(fn chunk -> hd(chunk) == target end)
    |> Enum.map(&length/1)
    |> Enum.max(fn -> 0 end)
  end

  defp calculate_overall_stats(group_stats, playoff_stats) do
    total_points = group_stats.points_earned + playoff_stats.total_points
    total_predictions = group_stats.total_finished + playoff_stats.total_predictions
    total_correct = group_stats.correct_results + playoff_stats.total_correct

    %{
      total_points: total_points,
      group_points: group_stats.points_earned,
      playoff_points: playoff_stats.total_points,
      total_predictions: total_predictions,
      total_correct: total_correct,
      overall_accuracy:
        if(total_predictions > 0,
          do: Float.round(total_correct / total_predictions * 100, 1),
          else: 0.0
        )
    }
  end
end

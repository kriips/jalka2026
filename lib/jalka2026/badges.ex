defmodule Jalka2026.Badges do
  @moduledoc """
  Handles achievement badge calculation and awarding.

  Prediction-based badges (awarded during the normal leaderboard recalculation):
  - first_blood: Made at least one correct prediction
  - perfect_match: Predicted at least one exact score correctly
  - sniper: Predicted 5+ exact scores correctly
  - prophet: 10+ correct results (outcome, not necessarily exact score)
  - underdog_picker: Correctly predicted 3+ upsets (a result fewer than 25% of all
    predictions for that match agreed with)
  - chaos_master: Correctly predicted 6+ upsets (as above)
  - draw_master: Correctly predicted 3+ draws
  - goal_machine: Predicted the exact score of a high-scoring match (5+ goals)
  - streak_master: Achieved a streak of 5+ consecutive correct predictions
  - cold_blood: Achieved a streak of 10+ consecutive correct predictions
  - group_guru: All results correct in at least one group
  - playoff_oracle: 5+ correct playoff predictions
  - bracket_master: Predicted all four semifinalists correctly

  Rank-based badges (awarded by `award_rank_badges/2` after the leaderboard is ranked):
  - leader: Reached rank 1 on the leaderboard
  - climber: Climbed 5+ ranks since the previous recalculation
  """

  import Ecto.Query

  alias Jalka2026.Accounts
  alias Jalka2026.Football.{GroupPrediction, Match, UserBadge}
  alias Jalka2026.Repo

  @type badge :: UserBadge.t()
  @type badges_by_user :: %{pos_integer() => [badge()]}

  # Prediction-based thresholds
  @prophet_results 10
  @sniper_scores 5
  @underdog_upsets 3
  @chaos_upsets 6
  @draw_master_draws 3
  @big_match_goals 5
  @streak_master_streak 5
  @cold_blood_streak 10
  @playoff_oracle_count 5
  @semifinal_phase 8
  @semifinalist_count 4

  # An "upset" is a correct prediction of a result that fewer than this share of all
  # predictions for that match agreed with.
  @underdog_threshold 0.25

  # Rank-based thresholds
  @climber_rank_gain 5

  @doc """
  Get all badges for a user.
  """
  def get_user_badges(user_id) do
    from(b in UserBadge,
      where: b.user_id == ^user_id,
      order_by: [asc: b.awarded_at]
    )
    |> Repo.all()
  end

  @doc """
  Get badges for multiple users at once. Returns a map of user_id => [badges].
  """
  def get_badges_for_users(user_ids) do
    from(b in UserBadge,
      where: b.user_id in ^user_ids,
      order_by: [asc: b.awarded_at]
    )
    |> Repo.all()
    |> Enum.group_by(& &1.user_id)
  end

  @doc """
  Recalculate and award badges for all users.
  Called during leaderboard recalculation.
  """
  def recalculate_all_badges do
    users = Accounts.list_users()
    finished_matches = get_finished_matches_ordered()
    playoff_results = get_playoff_results()
    distribution = load_prediction_distribution()

    now = now()
    all_existing_badges = get_all_existing_badge_types()

    badge_rows =
      Enum.flat_map(users, fn user ->
        predictions = get_user_predictions_map(user.id)
        playoff_predictions = get_user_playoff_predictions(user.id)
        existing_badges = Map.get(all_existing_badges, user.id, [])

        earned_badges =
          calculate_earned_badges(
            finished_matches,
            predictions,
            playoff_predictions,
            playoff_results,
            distribution
          )

        new_badge_rows(user.id, earned_badges -- existing_badges, now)
      end)

    insert_badge_rows(badge_rows)
  end

  @doc """
  Recalculate badges using pre-loaded data from leaderboard.
  Avoids duplicate queries for users, matches, predictions, and playoff results.
  `all_predictions_by_user` is a map of user_id => %{match_id => prediction}.
  """
  def recalculate_all_badges(users, finished_matches, playoff_results, all_predictions_by_user) do
    # Bulk-load all playoff predictions and existing badges in single queries
    all_playoff_predictions = get_all_playoff_predictions()
    all_existing_badges = get_all_existing_badge_types()

    # Build the per-match prediction distribution from the data already in memory
    # (no extra query) so the underdog/chaos badges can spot minority picks.
    distribution = build_prediction_distribution(all_predictions_by_user)

    now = now()

    badge_rows =
      Enum.flat_map(users, fn user ->
        user_predictions = Map.get(all_predictions_by_user, user.id, %{})
        playoff_predictions = Map.get(all_playoff_predictions, user.id, [])
        existing_badges = Map.get(all_existing_badges, user.id, [])

        earned_badges =
          calculate_earned_badges(
            finished_matches,
            user_predictions,
            playoff_predictions,
            playoff_results,
            distribution
          )

        new_badge_rows(user.id, earned_badges -- existing_badges, now)
      end)

    insert_badge_rows(badge_rows)
  end

  @doc """
  Recalculate badges for a single user.
  """
  def recalculate_user_badges(user_id, finished_matches, playoff_results) do
    predictions = get_user_predictions_map(user_id)
    playoff_predictions = get_user_playoff_predictions(user_id)
    existing_badges = get_existing_badge_types(user_id)
    distribution = load_prediction_distribution()

    earned_badges =
      calculate_earned_badges(
        finished_matches,
        predictions,
        playoff_predictions,
        playoff_results,
        distribution
      )

    insert_badge_rows(new_badge_rows(user_id, earned_badges -- existing_badges, now()))
  end

  @doc """
  Award rank-based badges from a freshly ranked leaderboard.

  Called after the leaderboard is recalculated, with the new and previous
  leaderboards (lists of `%Entry{}` or maps exposing `:user_id`, `:rank` and
  `:total_points`). Awards `leader` to anyone at rank 1 with points, and
  `climber` to anyone who gained 5+ ranks since the previous recalculation.
  """
  def award_rank_badges(new_leaderboard, old_leaderboard) do
    old_ranks = Map.new(old_leaderboard, fn entry -> {entry.user_id, entry.rank} end)
    all_existing_badges = get_all_existing_badge_types()
    now = now()

    badge_rows =
      Enum.flat_map(new_leaderboard, fn entry ->
        existing_badges = Map.get(all_existing_badges, entry.user_id, [])
        earned = rank_badges_for(entry, Map.get(old_ranks, entry.user_id))
        new_badge_rows(entry.user_id, earned -- existing_badges, now)
      end)

    insert_badge_rows(badge_rows)
  end

  # --- Prediction-based badge calculation ---

  # Calculate which prediction-based badges a user has earned
  defp calculate_earned_badges(
         finished_matches,
         predictions,
         playoff_predictions,
         playoff_results,
         distribution
       ) do
    stats = analyze_predictions(finished_matches, predictions, distribution)
    streak = calculate_max_streak(finished_matches, predictions)
    correct_playoff = count_correct_playoff(playoff_predictions, playoff_results)

    []
    |> award_if(stats.results >= 1, "first_blood")
    |> award_if(stats.scores >= 1, "perfect_match")
    |> award_if(stats.scores >= @sniper_scores, "sniper")
    |> award_if(stats.results >= @prophet_results, "prophet")
    |> award_if(stats.upsets >= @underdog_upsets, "underdog_picker")
    |> award_if(stats.upsets >= @chaos_upsets, "chaos_master")
    |> award_if(stats.draws >= @draw_master_draws, "draw_master")
    |> award_if(stats.big_scores >= 1, "goal_machine")
    |> award_if(streak >= @streak_master_streak, "streak_master")
    |> award_if(streak >= @cold_blood_streak, "cold_blood")
    |> award_if(has_perfect_group?(stats.groups), "group_guru")
    |> award_if(correct_playoff >= @playoff_oracle_count, "playoff_oracle")
    |> award_if(
      semifinalists_all_correct?(playoff_predictions, playoff_results),
      "bracket_master"
    )
  end

  defp award_if(badges, true, badge), do: [badge | badges]
  defp award_if(badges, false, _badge), do: badges

  # Rank-based badges for a single leaderboard entry
  defp rank_badges_for(entry, old_rank) do
    []
    |> award_if(entry.rank == 1 and entry.total_points > 0, "leader")
    |> award_if(climbed?(old_rank, entry.rank), "climber")
  end

  defp climbed?(old_rank, new_rank) when is_integer(old_rank),
    do: old_rank - new_rank >= @climber_rank_gain

  defp climbed?(_old_rank, _new_rank), do: false

  # Analyze all predictions and return a stats map
  defp analyze_predictions(finished_matches, predictions, distribution) do
    empty = %{results: 0, scores: 0, upsets: 0, draws: 0, big_scores: 0, groups: %{}}

    Enum.reduce(finished_matches, empty, fn match, acc ->
      prediction = Map.get(predictions, match.id)
      {result_correct, score_correct} = check_prediction(match, prediction)

      acc
      |> add(:results, result_correct)
      |> add(:scores, score_correct)
      |> add(:upsets, result_correct and rare_outcome?(match, distribution))
      |> add(:draws, result_correct and match.result == "draw")
      |> add(:big_scores, score_correct and match_total_goals(match) >= @big_match_goals)
      |> Map.update!(:groups, &track_group(&1, match, result_correct))
    end)
  end

  defp add(acc, _key, false), do: acc
  defp add(acc, key, true), do: Map.update!(acc, key, &(&1 + 1))

  # Track per-group correctness for the group_guru badge
  defp track_group(groups, %{group: nil}, _result_correct), do: groups

  defp track_group(groups, match, result_correct) do
    data = Map.get(groups, match.group, %{total: 0, correct: 0})

    Map.put(groups, match.group, %{
      total: data.total + 1,
      correct: data.correct + if(result_correct, do: 1, else: 0)
    })
  end

  # Check a single prediction against a match result
  defp check_prediction(_match, nil), do: {false, false}

  defp check_prediction(match, prediction) do
    result_correct = match.result == prediction.result

    score_correct =
      result_correct &&
        match.home_score == prediction.home_score &&
        match.away_score == prediction.away_score

    {result_correct, score_correct}
  end

  # An upset is a result that fewer than @underdog_threshold of all predictions
  # for that match agreed with. Combined with a correct result by the caller, it
  # marks a correctly-predicted minority pick.
  defp rare_outcome?(match, distribution) do
    case Map.get(distribution, match.id) do
      %{total: total, outcomes: outcomes} when total > 0 ->
        Map.get(outcomes, match.result, 0) / total < @underdog_threshold

      _ ->
        false
    end
  end

  defp match_total_goals(match), do: (match.home_score || 0) + (match.away_score || 0)

  # Calculate max streak from finished matches
  defp calculate_max_streak(finished_matches, predictions) do
    {_current, max_streak} =
      Enum.reduce(finished_matches, {0, 0}, fn match, {current, max} ->
        prediction = Map.get(predictions, match.id)

        if prediction && match.result == prediction.result do
          new_current = current + 1
          {new_current, max(new_current, max)}
        else
          {0, max}
        end
      end)

    max_streak
  end

  # Check if any group has all results correct
  defp has_perfect_group?(group_results) do
    Enum.any?(group_results, fn {_group, %{total: total, correct: correct}} ->
      total > 0 && total == correct
    end)
  end

  # Count correct playoff predictions
  defp count_correct_playoff(playoff_predictions, playoff_results) do
    result_set =
      MapSet.new(playoff_results, fn r -> {r.team_id, r.phase} end)

    Enum.count(playoff_predictions, fn pred ->
      MapSet.member?(result_set, {pred.team_id, pred.phase})
    end)
  end

  # Whether the user predicted all four semifinalists (phase 8 = QF winners) correctly
  defp semifinalists_all_correct?(playoff_predictions, playoff_results) do
    actual = phase_team_set(playoff_results, @semifinal_phase)
    predicted = phase_team_set(playoff_predictions, @semifinal_phase)

    MapSet.size(actual) == @semifinalist_count and MapSet.subset?(actual, predicted)
  end

  defp phase_team_set(rows, phase) do
    for row <- rows, row.phase == phase, into: MapSet.new(), do: row.team_id
  end

  # --- Prediction distribution (for upset/chaos badges) ---

  # Build %{match_id => %{total, outcomes}} from the already-loaded per-user map
  defp build_prediction_distribution(all_predictions_by_user) do
    Enum.reduce(all_predictions_by_user, %{}, fn {_user_id, by_match}, acc ->
      Enum.reduce(by_match, acc, fn {match_id, prediction}, inner ->
        add_outcome(
          inner,
          match_id,
          outcome_from_scores(prediction.home_score, prediction.away_score)
        )
      end)
    end)
  end

  # Build the same distribution directly from the database (single query)
  defp load_prediction_distribution do
    from(gp in GroupPrediction, select: {gp.match_id, gp.home_score, gp.away_score})
    |> Repo.all()
    |> Enum.reduce(%{}, fn {match_id, home_score, away_score}, acc ->
      add_outcome(acc, match_id, outcome_from_scores(home_score, away_score))
    end)
  end

  defp add_outcome(distribution, _match_id, nil), do: distribution

  defp add_outcome(distribution, match_id, outcome) do
    entry = Map.get(distribution, match_id, %{total: 0, outcomes: %{}})

    Map.put(distribution, match_id, %{
      total: entry.total + 1,
      outcomes: Map.update(entry.outcomes, outcome, 1, &(&1 + 1))
    })
  end

  defp outcome_from_scores(home_score, away_score)
       when is_integer(home_score) and is_integer(away_score) do
    cond do
      home_score > away_score -> "home"
      home_score < away_score -> "away"
      true -> "draw"
    end
  end

  defp outcome_from_scores(_home_score, _away_score), do: nil

  # --- Persistence helpers ---

  defp new_badge_rows(user_id, badge_types, now) do
    Enum.map(badge_types, fn badge_type ->
      %{
        user_id: user_id,
        badge_type: badge_type,
        awarded_at: now,
        inserted_at: now,
        updated_at: now
      }
    end)
  end

  defp insert_badge_rows([]), do: {:ok, %{insert_badges: {0, nil}}}

  defp insert_badge_rows(badge_rows) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert_all(:insert_badges, UserBadge, badge_rows, on_conflict: :nothing)
    |> Repo.transaction()
  end

  defp now, do: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

  # --- Data loaders ---

  # Get finished matches ordered by date
  defp get_finished_matches_ordered do
    from(m in Match,
      where: m.finished == true,
      order_by: [asc: m.date],
      preload: [:home_team, :away_team]
    )
    |> Repo.all()
  end

  # Get user predictions as a map keyed by match_id
  defp get_user_predictions_map(user_id) do
    from(gp in GroupPrediction,
      where: gp.user_id == ^user_id
    )
    |> Repo.all()
    |> Map.new(fn p -> {p.match_id, p} end)
  end

  # Get user playoff predictions
  defp get_user_playoff_predictions(user_id) do
    from(pp in Jalka2026.Football.PlayoffPrediction,
      where: pp.user_id == ^user_id
    )
    |> Repo.all()
  end

  # Get playoff results
  defp get_playoff_results do
    Repo.all(Jalka2026.Football.PlayoffResult)
  end

  # Get existing badge types for a user
  defp get_existing_badge_types(user_id) do
    from(b in UserBadge,
      where: b.user_id == ^user_id,
      select: b.badge_type
    )
    |> Repo.all()
  end

  # Bulk-load all existing badge types grouped by user_id
  defp get_all_existing_badge_types do
    from(b in UserBadge,
      select: {b.user_id, b.badge_type}
    )
    |> Repo.all()
    |> Enum.group_by(fn {uid, _type} -> uid end, fn {_uid, type} -> type end)
  end

  # Bulk-load all playoff predictions grouped by user_id
  defp get_all_playoff_predictions do
    from(pp in Jalka2026.Football.PlayoffPrediction)
    |> Repo.all()
    |> Enum.group_by(& &1.user_id)
  end
end

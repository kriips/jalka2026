defmodule Jalka2026.Badges do
  @moduledoc """
  Handles achievement badge calculation and awarding.

  Badges are awarded based on prediction performance:
  - perfect_match: Predicted at least one exact score correctly
  - prophet: 10+ correct results (outcome, not necessarily exact score)
  - underdog_picker: Correctly predicted 3+ upsets (away wins with odds against)
  - streak_master: Achieved a streak of 5+ consecutive correct predictions
  - group_guru: All results correct in at least one group
  - playoff_oracle: 5+ correct playoff predictions
  - first_blood: Made at least one correct prediction
  """

  import Ecto.Query
  alias Jalka2026.Repo
  alias Jalka2026.Football.{UserBadge, GroupPrediction, Match}
  alias Jalka2026.Accounts

  @type badge :: UserBadge.t()
  @type badges_by_user :: %{pos_integer() => [badge()]}

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

    Enum.each(users, fn user ->
      recalculate_user_badges(user.id, finished_matches, playoff_results)
    end)
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

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Enum.each(users, fn user ->
      user_predictions = Map.get(all_predictions_by_user, user.id, %{})
      playoff_predictions = Map.get(all_playoff_predictions, user.id, [])
      existing_badges = Map.get(all_existing_badges, user.id, [])

      earned_badges = calculate_earned_badges(
        finished_matches,
        user_predictions,
        playoff_predictions,
        playoff_results
      )

      new_badges = earned_badges -- existing_badges

      Enum.each(new_badges, fn badge_type ->
        %UserBadge{}
        |> UserBadge.changeset(%{
          user_id: user.id,
          badge_type: badge_type,
          awarded_at: now
        })
        |> Repo.insert(on_conflict: :nothing)
      end)
    end)
  end

  @doc """
  Recalculate badges for a single user.
  """
  def recalculate_user_badges(user_id, finished_matches, playoff_results) do
    predictions = get_user_predictions_map(user_id)
    playoff_predictions = get_user_playoff_predictions(user_id)
    existing_badges = get_existing_badge_types(user_id)

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    earned_badges = calculate_earned_badges(
      finished_matches,
      predictions,
      playoff_predictions,
      playoff_results
    )

    # Award new badges that haven't been awarded yet
    new_badges = earned_badges -- existing_badges

    Enum.each(new_badges, fn badge_type ->
      %UserBadge{}
      |> UserBadge.changeset(%{
        user_id: user_id,
        badge_type: badge_type,
        awarded_at: now
      })
      |> Repo.insert(on_conflict: :nothing)
    end)
  end

  # Calculate which badges a user has earned based on their predictions
  defp calculate_earned_badges(finished_matches, predictions, playoff_predictions, playoff_results) do
    badges = []

    {correct_results, correct_scores, upsets_correct, group_results} =
      analyze_predictions(finished_matches, predictions)

    streak = calculate_max_streak(finished_matches, predictions)

    # first_blood: at least one correct prediction
    badges = if correct_results >= 1, do: ["first_blood" | badges], else: badges

    # perfect_match: at least one exact score prediction
    badges = if correct_scores >= 1, do: ["perfect_match" | badges], else: badges

    # prophet: 10+ correct results
    badges = if correct_results >= 10, do: ["prophet" | badges], else: badges

    # underdog_picker: 3+ correctly predicted upsets
    badges = if upsets_correct >= 3, do: ["underdog_picker" | badges], else: badges

    # streak_master: achieved a 5+ streak
    badges = if streak >= 5, do: ["streak_master" | badges], else: badges

    # group_guru: all results correct in at least one group
    badges = if has_perfect_group?(group_results), do: ["group_guru" | badges], else: badges

    # playoff_oracle: 5+ correct playoff predictions
    correct_playoff = count_correct_playoff(playoff_predictions, playoff_results)
    badges = if correct_playoff >= 5, do: ["playoff_oracle" | badges], else: badges

    badges
  end

  # Analyze all predictions and return stats
  defp analyze_predictions(finished_matches, predictions) do
    Enum.reduce(finished_matches, {0, 0, 0, %{}}, fn match, {results, scores, upsets, groups} ->
      prediction = Map.get(predictions, match.id)

      {result_correct, score_correct, upset_correct} =
        check_prediction(match, prediction)

      new_results = if result_correct, do: results + 1, else: results
      new_scores = if score_correct, do: scores + 1, else: scores
      new_upsets = if upset_correct, do: upsets + 1, else: upsets

      # Track per-group correctness
      new_groups =
        if match.group do
          group_data = Map.get(groups, match.group, %{total: 0, correct: 0})
          group_data = %{
            total: group_data.total + 1,
            correct: group_data.correct + (if result_correct, do: 1, else: 0)
          }
          Map.put(groups, match.group, group_data)
        else
          groups
        end

      {new_results, new_scores, new_upsets, new_groups}
    end)
  end

  # Check a single prediction against a match result
  defp check_prediction(_match, nil), do: {false, false, false}

  defp check_prediction(match, prediction) do
    result_correct = match.result == prediction.result

    score_correct =
      result_correct &&
        match.home_score == prediction.home_score &&
        match.away_score == prediction.away_score

    # An upset is when the away team wins
    upset_correct = result_correct && match.result == "away"

    {result_correct, score_correct, upset_correct}
  end

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

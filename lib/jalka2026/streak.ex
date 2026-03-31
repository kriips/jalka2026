defmodule Jalka2026.Streak do
  @moduledoc """
  Handles prediction streak tracking and bonus points calculation.

  A streak is a consecutive sequence of correct predictions (result only, not exact score).
  Bonus points are awarded for maintaining streaks of 5+ correct predictions:
  - Streak of 5: +1 bonus point
  - Streak of 6: +1 bonus point (total +2)
  - Streak of 7+: +1 bonus point per additional correct prediction
  """

  import Ecto.Query
  alias Jalka2026.Repo
  alias Jalka2026.Football.{UserStreak, GroupPrediction, Match}
  alias Jalka2026.Accounts
  alias Jalka2026.Scoring

  @doc """
  Get or create a user streak record.
  """
  def get_or_create_streak(user_id) do
    case Repo.get_by(UserStreak, user_id: user_id) do
      nil ->
        %UserStreak{}
        |> UserStreak.changeset(%{user_id: user_id})
        |> Repo.insert!()

      streak ->
        streak
    end
  end

  @doc """
  Get streak data for a user.
  Returns %{current_streak: int, longest_streak: int, bonus_points: int}
  """
  def get_user_streak(user_id) do
    case Repo.get_by(UserStreak, user_id: user_id) do
      nil ->
        %{current_streak: 0, longest_streak: 0, bonus_points: 0}

      streak ->
        %{
          current_streak: streak.current_streak,
          longest_streak: streak.longest_streak,
          bonus_points: streak.bonus_points
        }
    end
  end

  @doc """
  Get all streak data indexed by user_id.
  """
  def get_all_streaks do
    UserStreak
    |> Repo.all()
    |> Map.new(fn streak ->
      {streak.user_id,
       %{
         current_streak: streak.current_streak,
         longest_streak: streak.longest_streak,
         bonus_points: streak.bonus_points
       }}
    end)
  end

  @doc """
  Recalculate all streaks for all users based on finished matches.
  This is called after match results are entered.
  """
  def recalculate_all_streaks do
    users = Accounts.list_users()
    finished_matches = get_finished_matches_ordered()

    Enum.each(users, fn user ->
      calculate_and_save_streak(user.id, finished_matches)
    end)

    get_all_streaks()
  end

  @doc """
  Recalculate all streaks using pre-loaded data from leaderboard.
  Avoids duplicate queries for users, matches, and predictions.
  `all_predictions_by_user` is a map of user_id => %{match_id => prediction}.
  """
  def recalculate_all_streaks(users, finished_matches, all_predictions_by_user) do
    # Bulk-load existing streaks to avoid N+1 get_or_create per user
    existing_streaks = get_all_streak_records()

    Enum.each(users, fn user ->
      user_predictions = Map.get(all_predictions_by_user, user.id, %{})
      {current, longest, bonus} = calculate_streak_stats(finished_matches, user_predictions)

      streak = Map.get(existing_streaks, user.id) || create_streak(user.id)

      streak
      |> UserStreak.changeset(%{
        current_streak: current,
        longest_streak: longest,
        bonus_points: bonus
      })
      |> Repo.update!()
    end)

    get_all_streaks()
  end

  @doc """
  Calculate streak for a single user and save to database.
  """
  def calculate_and_save_streak(user_id, finished_matches) do
    predictions = get_user_predictions_map(user_id)
    {current, longest, bonus} = calculate_streak_stats(finished_matches, predictions)

    streak = get_or_create_streak(user_id)

    streak
    |> UserStreak.changeset(%{
      current_streak: current,
      longest_streak: longest,
      bonus_points: bonus
    })
    |> Repo.update!()

    %{current_streak: current, longest_streak: longest, bonus_points: bonus}
  end

  @doc """
  Calculate streak statistics from finished matches and predictions.
  Returns {current_streak, longest_streak, bonus_points}.

  Delegates to `Jalka2026.Scoring.calculate_streak_stats/2`.
  """
  defdelegate calculate_streak_stats(finished_matches, predictions), to: Scoring

  # Get finished matches ordered by date
  defp get_finished_matches_ordered do
    from(m in Match,
      where: m.finished == true,
      order_by: [asc: m.date]
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

  # Bulk-load all streak records as %{user_id => %UserStreak{}}
  defp get_all_streak_records do
    UserStreak
    |> Repo.all()
    |> Map.new(fn s -> {s.user_id, s} end)
  end

  # Create a new streak record
  defp create_streak(user_id) do
    %UserStreak{}
    |> UserStreak.changeset(%{user_id: user_id})
    |> Repo.insert!()
  end
end

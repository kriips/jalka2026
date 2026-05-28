defmodule Jalka2026.RivalryNotifications do
  @moduledoc """
  Handles real-time notifications for rivalry-related events.

  Uses Phoenix.PubSub to broadcast when:
  - A rival makes a different prediction
  - Rivalry statistics change
  """

  @pubsub Jalka2026.PubSub

  @doc """
  Returns the PubSub topic for a user's rivalry notifications.
  """
  def user_topic(user_id), do: "user:#{user_id}:rivalries"

  @doc """
  Subscribe the current process to rivalry notifications for a user.
  """
  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, user_topic(user_id))
  end

  @doc """
  Broadcast a notification when a rival makes a different prediction.

  ## Parameters
    - user_id: The user to notify
    - rival_id: The rival who made the prediction
    - match_id: The match the prediction is for
    - rival_prediction: The rival's prediction
    - user_prediction: The user's prediction (for comparison)
  """
  def broadcast_differing_prediction(
        user_id,
        rival_id,
        match_id,
        rival_prediction,
        user_prediction
      ) do
    Phoenix.PubSub.broadcast(@pubsub, user_topic(user_id), {
      :rivalry_prediction_diff,
      %{
        rival_id: rival_id,
        match_id: match_id,
        rival_prediction: rival_prediction,
        user_prediction: user_prediction
      }
    })
  end

  @doc """
  Check all rivalries and broadcast notifications for differing predictions.
  Called after a user makes a prediction.

  ## Parameters
    - user_id: The user who made the prediction
    - match_id: The match the prediction was made for
    - prediction: The prediction details (home_score, away_score, result)
  """
  def check_and_notify_rivals(user_id, match_id, prediction) do
    alias Jalka2026.Football

    # Get all rivalries where notifications are enabled
    # Both users who added this user as rival, and users this user added as rival
    rivalries = Football.get_rivalries_with_notifications(user_id)

    # Also check if any other users have this user as a rival
    # For each rivalry, check if the other user has a different prediction
    Enum.each(rivalries, fn rivalry ->
      rival_id = rivalry.rival_id
      rival_prediction = Football.get_prediction_by_user_match(rival_id, match_id)

      if rival_prediction && prediction_result_differs?(prediction, rival_prediction) do
        # Notify the current user that their rival has a different prediction
        broadcast_differing_prediction(
          user_id,
          rival_id,
          match_id,
          %{
            home_score: rival_prediction.home_score,
            away_score: rival_prediction.away_score,
            result: rival_prediction.result
          },
          %{
            home_score: prediction.home_score,
            away_score: prediction.away_score,
            result: prediction.result
          }
        )
      end
    end)

    # Also notify users who have this user as a rival
    notify_users_who_have_rival(user_id, match_id, prediction)
  end

  defp notify_users_who_have_rival(user_id, match_id, prediction) do
    alias Jalka2026.Football
    alias Jalka2026.Repo
    import Ecto.Query

    # Find users who have this user as a rival with notifications enabled
    query =
      from(ur in Football.UserRivalry,
        where:
          ur.rival_id == ^user_id and ur.status == "active" and ur.notifications_enabled == true,
        select: ur.user_id
      )

    users_with_this_rival = Repo.all(query)

    Enum.each(users_with_this_rival, fn other_user_id ->
      other_prediction = Football.get_prediction_by_user_match(other_user_id, match_id)

      if other_prediction && prediction_result_differs?(prediction, other_prediction) do
        broadcast_differing_prediction(
          other_user_id,
          user_id,
          match_id,
          %{
            home_score: prediction.home_score,
            away_score: prediction.away_score,
            result: prediction.result
          },
          %{
            home_score: other_prediction.home_score,
            away_score: other_prediction.away_score,
            result: other_prediction.result
          }
        )
      end
    end)
  end

  defp prediction_result_differs?(pred1, pred2) do
    get_result(pred1) != get_result(pred2)
  end

  defp get_result(%{result: result}), do: result
  defp get_result(pred) when is_map(pred), do: Map.get(pred, :result)
end

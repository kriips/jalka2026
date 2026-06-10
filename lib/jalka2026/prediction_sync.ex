defmodule Jalka2026.PredictionSync do
  @moduledoc """
  Handles real-time synchronization of predictions across devices.

  Uses Phoenix.PubSub to broadcast prediction changes to all connected
  LiveView sessions for a given user, enabling seamless multi-device editing.
  """

  @pubsub Jalka2026.PubSub

  @doc """
  Returns the PubSub topic for a user's predictions.
  """
  def user_topic(user_id), do: "user:#{user_id}:predictions"

  @doc """
  Subscribe the current process to prediction updates for a user.
  Call this in LiveView mount/3 to receive sync messages.
  """
  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, user_topic(user_id))
  end

  @doc """
  Broadcast a group prediction change to all subscribed processes.

  The `source_pid` is excluded from receiving the broadcast to avoid
  redundant updates on the device that made the change.

  ## Parameters
    - user_id: The user whose prediction changed
    - match_id: The match the prediction is for
    - home_score: The new home score
    - away_score: The new away score
    - source_pid: The PID of the process that made the change (to exclude)
  """
  def broadcast_group_prediction(user_id, match_id, home_score, away_score, source_pid \\ nil) do
    Phoenix.PubSub.broadcast(@pubsub, user_topic(user_id), {
      :prediction_sync,
      :group_prediction_changed,
      %{
        match_id: match_id,
        home_score: home_score,
        away_score: away_score,
        source_pid: source_pid
      }
    })
  end

  @doc """
  Broadcast a playoff prediction change to all subscribed processes.

  ## Parameters
    - user_id: The user whose prediction changed
    - team_id: The team being toggled
    - phase: The playoff phase (32, 16, 8, 4, 2, 1)
    - include: Whether the team was added or removed
    - source_pid: The PID of the process that made the change (to exclude)
  """
  def broadcast_playoff_prediction(user_id, team_id, phase, include, source_pid \\ nil) do
    Phoenix.PubSub.broadcast(@pubsub, user_topic(user_id), {
      :prediction_sync,
      :playoff_prediction_changed,
      %{
        team_id: team_id,
        phase: phase,
        include: include,
        source_pid: source_pid
      }
    })
  end

  @doc """
  Broadcast that the user's whole playoff bracket was reset (all picks cleared).

  ## Parameters
    - user_id: The user whose bracket was reset
    - source_pid: The PID of the process that made the change (to exclude)
  """
  def broadcast_playoff_bracket_reset(user_id, source_pid \\ nil) do
    Phoenix.PubSub.broadcast(@pubsub, user_topic(user_id), {
      :prediction_sync,
      :playoff_bracket_reset,
      %{source_pid: source_pid}
    })
  end
end

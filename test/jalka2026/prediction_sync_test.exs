defmodule Jalka2026.PredictionSyncTest do
  use ExUnit.Case, async: true

  alias Jalka2026.PredictionSync

  describe "user_topic/1" do
    test "returns correct topic format" do
      assert PredictionSync.user_topic(1) == "user:1:predictions"
      assert PredictionSync.user_topic(42) == "user:42:predictions"
    end
  end

  describe "subscribe/1" do
    test "subscribes to user prediction topic" do
      assert PredictionSync.subscribe(1) == :ok
    end
  end

  describe "broadcast_group_prediction/4" do
    test "broadcasts group prediction change" do
      # Subscribe first to verify broadcast
      PredictionSync.subscribe(1)

      PredictionSync.broadcast_group_prediction(1, 10, 2, 1)

      assert_receive {:prediction_sync, :group_prediction_changed,
                       %{match_id: 10, home_score: 2, away_score: 1}}
    end

    test "includes source_pid in broadcast" do
      PredictionSync.subscribe(2)
      pid = self()

      PredictionSync.broadcast_group_prediction(2, 10, 2, 1, pid)

      assert_receive {:prediction_sync, :group_prediction_changed,
                       %{match_id: 10, source_pid: ^pid}}
    end
  end

  describe "broadcast_playoff_prediction/4" do
    test "broadcasts playoff prediction change" do
      PredictionSync.subscribe(3)

      PredictionSync.broadcast_playoff_prediction(3, 5, 16, true)

      assert_receive {:prediction_sync, :playoff_prediction_changed,
                       %{team_id: 5, phase: 16, include: true}}
    end

    test "includes source_pid in broadcast" do
      PredictionSync.subscribe(4)
      pid = self()

      PredictionSync.broadcast_playoff_prediction(4, 5, 16, false, pid)

      assert_receive {:prediction_sync, :playoff_prediction_changed,
                       %{team_id: 5, phase: 16, include: false, source_pid: ^pid}}
    end
  end
end

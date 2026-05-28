defmodule Jalka2026.RivalryNotificationsTest do
  use ExUnit.Case, async: true

  alias Jalka2026.RivalryNotifications

  describe "user_topic/1" do
    test "returns correct topic format" do
      assert RivalryNotifications.user_topic(1) == "user:1:rivalries"
      assert RivalryNotifications.user_topic(42) == "user:42:rivalries"
    end
  end

  describe "subscribe/1" do
    test "subscribes to user rivalry topic" do
      assert RivalryNotifications.subscribe(1) == :ok
    end
  end

  describe "broadcast_differing_prediction/5" do
    test "broadcasts prediction difference notification" do
      RivalryNotifications.subscribe(1)

      RivalryNotifications.broadcast_differing_prediction(
        1,
        2,
        10,
        %{home_score: 2, away_score: 1, result: "home"},
        %{home_score: 0, away_score: 1, result: "away"}
      )

      assert_receive {:rivalry_prediction_diff,
                      %{
                        rival_id: 2,
                        match_id: 10,
                        rival_prediction: %{result: "home"},
                        user_prediction: %{result: "away"}
                      }}
    end
  end
end

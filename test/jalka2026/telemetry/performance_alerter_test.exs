defmodule Jalka2026.Telemetry.PerformanceAlerterTest do
  use ExUnit.Case, async: true

  alias Jalka2026.Telemetry.PerformanceAlerter

  describe "get_thresholds/0" do
    test "returns a map with all required threshold keys" do
      thresholds = PerformanceAlerter.get_thresholds()
      assert is_map(thresholds)
      assert Map.has_key?(thresholds, :prediction_group)
      assert Map.has_key?(thresholds, :prediction_playoff)
      assert Map.has_key?(thresholds, :leaderboard_calculation)
      assert Map.has_key?(thresholds, :live_view_mount)
      assert Map.has_key?(thresholds, :live_view_event)
      assert Map.has_key?(thresholds, :match_simulation)
    end

    test "all threshold values are positive integers (milliseconds)" do
      thresholds = PerformanceAlerter.get_thresholds()

      Enum.each(thresholds, fn {key, value} ->
        assert is_integer(value) and value > 0,
               "Threshold #{key} should be a positive integer (got #{inspect(value)})"
      end)
    end

    test "prediction thresholds are lower than simulation threshold" do
      thresholds = PerformanceAlerter.get_thresholds()
      # Simulations are expected to take longer than individual predictions
      assert thresholds.match_simulation > thresholds.prediction_group,
             "Simulation threshold should be higher than prediction threshold"

      assert thresholds.match_simulation > thresholds.prediction_playoff,
             "Simulation threshold should be higher than playoff prediction threshold"
    end

    test "leaderboard threshold is higher than individual request thresholds" do
      thresholds = PerformanceAlerter.get_thresholds()
      # Leaderboard calculation processes all users and matches so takes longer
      assert thresholds.leaderboard_calculation > thresholds.prediction_group,
             "Leaderboard calculation should have a higher threshold than individual predictions"
    end
  end

  describe "handle_telemetry_event/4 behavior" do
    test "records metric and creates alert when duration exceeds threshold" do
      thresholds = PerformanceAlerter.get_thresholds()
      threshold = thresholds.prediction_group

      # Send a measurement that exceeds the threshold
      excessive_duration_native = System.convert_time_unit(threshold + 100, :millisecond, :native)

      # Emit via telemetry which the PerformanceAlerter is attached to
      :telemetry.execute(
        [:jalka2026, :prediction, :group, :stop],
        %{duration: excessive_duration_native},
        %{user_id: 1, match_id: 1}
      )

      # Give the GenServer time to process the cast
      Process.sleep(50)

      stats = PerformanceAlerter.get_stats()

      # Verify the metric was recorded
      prediction_stats = Map.get(stats.stats, :prediction_group)
      assert prediction_stats != nil, "Expected prediction_group metrics to be recorded"
      assert prediction_stats.count >= 1

      # Verify an alert was created for the threshold violation
      assert prediction_stats.violations >= 1,
             "Expected at least 1 threshold violation"
    end

    test "does not create alert when duration is within threshold" do
      thresholds = PerformanceAlerter.get_thresholds()
      threshold = thresholds.prediction_playoff

      # Send a measurement well within the threshold
      safe_duration_native = System.convert_time_unit(div(threshold, 2), :millisecond, :native)

      initial_stats = PerformanceAlerter.get_stats()
      initial_alerts = length(initial_stats.recent_alerts)

      :telemetry.execute(
        [:jalka2026, :prediction, :playoff, :stop],
        %{duration: safe_duration_native},
        %{user_id: 2, team_id: 5, phase: 16}
      )

      Process.sleep(50)

      stats = PerformanceAlerter.get_stats()
      new_alerts = length(stats.recent_alerts)

      # No new threshold-exceeded alerts should have been added
      assert new_alerts == initial_alerts,
             "Expected no new alerts for duration within threshold (got #{new_alerts - initial_alerts} new alerts)"
    end

    test "get_stats returns expected structure" do
      stats = PerformanceAlerter.get_stats()
      assert is_map(stats)
      assert Map.has_key?(stats, :stats)
      assert Map.has_key?(stats, :recent_alerts)
      assert is_map(stats.stats)
      assert is_list(stats.recent_alerts)
    end
  end
end

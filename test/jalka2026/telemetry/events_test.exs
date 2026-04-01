defmodule Jalka2026.Telemetry.EventsTest do
  use ExUnit.Case, async: true

  alias Jalka2026.Telemetry.Events

  # Helper to attach a telemetry handler and collect events in the test process
  defp attach_test_handler(event_name) do
    handler_id = "test-handler-#{inspect(event_name)}-#{System.unique_integer()}"

    :telemetry.attach(
      handler_id,
      event_name,
      fn name, measurements, metadata, _ ->
        send(self(), {:telemetry_event, name, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    handler_id
  end

  describe "span_group_prediction/2" do
    test "executes the provided function and returns its result" do
      metadata = %{user_id: 1, match_id: 1}
      result = Events.span_group_prediction(metadata, fn -> {:ok, :test} end)
      assert result == {:ok, :test}
    end

    test "emits telemetry start and stop events with correct event names" do
      attach_test_handler([:jalka2026, :prediction, :group, :start])
      attach_test_handler([:jalka2026, :prediction, :group, :stop])

      metadata = %{user_id: 42, match_id: 7}
      Events.span_group_prediction(metadata, fn -> :done end)

      assert_receive {:telemetry_event, [:jalka2026, :prediction, :group, :start], _measurements, recv_meta}
      assert recv_meta.user_id == 42
      assert recv_meta.match_id == 7

      assert_receive {:telemetry_event, [:jalka2026, :prediction, :group, :stop], stop_measurements, _stop_meta}
      assert Map.has_key?(stop_measurements, :duration)
    end
  end

  describe "span_playoff_prediction/2" do
    test "executes the provided function and returns its result" do
      metadata = %{user_id: 1, team_id: 1, phase: 16, action: :add}
      result = Events.span_playoff_prediction(metadata, fn -> {:ok, :test} end)
      assert result == {:ok, :test}
    end

    test "emits telemetry start and stop events" do
      attach_test_handler([:jalka2026, :prediction, :playoff, :start])
      attach_test_handler([:jalka2026, :prediction, :playoff, :stop])

      metadata = %{user_id: 5, team_id: 10, phase: 16, action: :add}
      Events.span_playoff_prediction(metadata, fn -> :ok end)

      assert_receive {:telemetry_event, [:jalka2026, :prediction, :playoff, :start], _m, recv_meta}
      assert recv_meta.user_id == 5
      assert recv_meta.phase == 16

      assert_receive {:telemetry_event, [:jalka2026, :prediction, :playoff, :stop], stop_m, _meta}
      assert Map.has_key?(stop_m, :duration)
    end
  end

  describe "span_leaderboard_calculation/2" do
    test "executes the provided function and returns its result" do
      metadata = %{user_count: 10, match_count: 5}
      result = Events.span_leaderboard_calculation(metadata, fn -> :calculated end)
      assert result == :calculated
    end

    test "emits telemetry start and stop events" do
      attach_test_handler([:jalka2026, :leaderboard, :calculation, :start])
      attach_test_handler([:jalka2026, :leaderboard, :calculation, :stop])

      metadata = %{user_count: 3, match_count: 2}
      Events.span_leaderboard_calculation(metadata, fn -> :done end)

      assert_receive {:telemetry_event, [:jalka2026, :leaderboard, :calculation, :start], _m, recv_meta}
      assert recv_meta.user_count == 3

      assert_receive {:telemetry_event, [:jalka2026, :leaderboard, :calculation, :stop], stop_m, _meta}
      assert Map.has_key?(stop_m, :duration)
    end
  end

  describe "span_live_view_mount/2" do
    test "executes the provided function and returns its result" do
      metadata = %{view: "TestView", connected: true}
      result = Events.span_live_view_mount(metadata, fn -> {:ok, :mounted} end)
      assert result == {:ok, :mounted}
    end

    test "emits telemetry start and stop events with view metadata" do
      attach_test_handler([:jalka2026, :live_view, :mount, :start])
      attach_test_handler([:jalka2026, :live_view, :mount, :stop])

      metadata = %{view: "LeaderboardLive", connected: false}
      Events.span_live_view_mount(metadata, fn -> :ok end)

      assert_receive {:telemetry_event, [:jalka2026, :live_view, :mount, :start], _m, recv_meta}
      assert recv_meta.view == "LeaderboardLive"
      assert recv_meta.connected == false

      assert_receive {:telemetry_event, [:jalka2026, :live_view, :mount, :stop], stop_m, _meta}
      assert Map.has_key?(stop_m, :duration)
    end
  end

  describe "span_live_view_event/2" do
    test "executes the provided function and returns its result" do
      metadata = %{view: "TestView", event: "click"}
      result = Events.span_live_view_event(metadata, fn -> {:ok, :handled} end)
      assert result == {:ok, :handled}
    end

    test "emits telemetry start and stop events" do
      attach_test_handler([:jalka2026, :live_view, :handle_event, :start])
      attach_test_handler([:jalka2026, :live_view, :handle_event, :stop])

      metadata = %{view: "GameLive", event: "save_prediction"}
      Events.span_live_view_event(metadata, fn -> :ok end)

      assert_receive {:telemetry_event, [:jalka2026, :live_view, :handle_event, :start], _m, recv_meta}
      assert recv_meta.event == "save_prediction"

      assert_receive {:telemetry_event, [:jalka2026, :live_view, :handle_event, :stop], stop_m, _meta}
      assert Map.has_key?(stop_m, :duration)
    end
  end

  describe "span_match_simulation/2" do
    test "executes the provided function and returns its result" do
      metadata = %{home_team: "GER", away_team: "FRA", simulation_count: 1000}
      result = Events.span_match_simulation(metadata, fn -> %{home_win: 50.0} end)
      assert result == %{home_win: 50.0}
    end

    test "emits telemetry start and stop events with team metadata" do
      attach_test_handler([:jalka2026, :simulation, :match, :start])
      attach_test_handler([:jalka2026, :simulation, :match, :stop])

      metadata = %{home_team: "BRA", away_team: "ARG", simulation_count: 100}
      Events.span_match_simulation(metadata, fn -> %{result: :done} end)

      assert_receive {:telemetry_event, [:jalka2026, :simulation, :match, :start], _m, recv_meta}
      assert recv_meta.home_team == "BRA"
      assert recv_meta.away_team == "ARG"

      assert_receive {:telemetry_event, [:jalka2026, :simulation, :match, :stop], stop_m, _meta}
      assert Map.has_key?(stop_m, :duration)
    end
  end

  describe "emit_prediction_count/1" do
    test "accepts :group type" do
      assert Events.emit_prediction_count(:group) == :ok
    end

    test "accepts :playoff type" do
      assert Events.emit_prediction_count(:playoff) == :ok
    end

    test "emits a telemetry event with count measurement for :group" do
      attach_test_handler([:jalka2026, :prediction, :group, :count])

      Events.emit_prediction_count(:group)

      assert_receive {:telemetry_event, [:jalka2026, :prediction, :group, :count], measurements, _meta}
      assert measurements.count == 1
    end

    test "emits a telemetry event with count measurement for :playoff" do
      attach_test_handler([:jalka2026, :prediction, :playoff, :count])

      Events.emit_prediction_count(:playoff)

      assert_receive {:telemetry_event, [:jalka2026, :prediction, :playoff, :count], measurements, _meta}
      assert measurements.count == 1
    end
  end

  describe "emit_page_view/1" do
    test "emits page view event" do
      assert Events.emit_page_view("leaderboard") == :ok
    end

    test "accepts metadata" do
      assert Events.emit_page_view("predictions", %{user_id: 1}) == :ok
    end

    test "emits telemetry event with view name in metadata" do
      attach_test_handler([:jalka2026, :page, :view])

      Events.emit_page_view("my_page")

      assert_receive {:telemetry_event, [:jalka2026, :page, :view], measurements, metadata}
      assert measurements.count == 1
      assert metadata.view == "my_page"
    end

    test "emits telemetry event with extra metadata" do
      attach_test_handler([:jalka2026, :page, :view])

      Events.emit_page_view("predictions", %{user_id: 99})

      assert_receive {:telemetry_event, [:jalka2026, :page, :view], _measurements, metadata}
      assert metadata.view == "predictions"
      assert metadata.user_id == 99
    end
  end

  describe "span_prediction_load/2" do
    test "executes the provided function and returns its result" do
      metadata = %{source: :all_predictions_indexed}
      result = Events.span_prediction_load(metadata, fn -> {:ok, %{}} end)
      assert result == {:ok, %{}}
    end

    test "emits telemetry start and stop events" do
      attach_test_handler([:jalka2026, :query_group, :prediction_load, :start])
      attach_test_handler([:jalka2026, :query_group, :prediction_load, :stop])

      metadata = %{source: :all_predictions_by_user}
      Events.span_prediction_load(metadata, fn -> :done end)

      assert_receive {:telemetry_event, [:jalka2026, :query_group, :prediction_load, :start], _m, recv_meta}
      assert recv_meta.source == :all_predictions_by_user

      assert_receive {:telemetry_event, [:jalka2026, :query_group, :prediction_load, :stop], stop_m, _meta}
      assert Map.has_key?(stop_m, :duration)
    end
  end

  describe "span_match_listing/2" do
    test "executes the provided function and returns its result" do
      metadata = %{source: :matches_by_group, group: "A"}
      result = Events.span_match_listing(metadata, fn -> [{:match, 1}] end)
      assert result == [{:match, 1}]
    end

    test "emits telemetry start and stop events with source metadata" do
      attach_test_handler([:jalka2026, :query_group, :match_listing, :start])
      attach_test_handler([:jalka2026, :query_group, :match_listing, :stop])

      metadata = %{source: :finished_matches}
      Events.span_match_listing(metadata, fn -> [] end)

      assert_receive {:telemetry_event, [:jalka2026, :query_group, :match_listing, :start], _m, recv_meta}
      assert recv_meta.source == :finished_matches

      assert_receive {:telemetry_event, [:jalka2026, :query_group, :match_listing, :stop], stop_m, _meta}
      assert Map.has_key?(stop_m, :duration)
    end
  end

  describe "span_leaderboard_data_load/2" do
    test "executes the provided function and returns its result" do
      metadata = %{source: :recalculate_leaderboard}
      result = Events.span_leaderboard_data_load(metadata, fn -> {:data, :loaded} end)
      assert result == {:data, :loaded}
    end

    test "emits telemetry start and stop events" do
      attach_test_handler([:jalka2026, :query_group, :leaderboard_data_load, :start])
      attach_test_handler([:jalka2026, :query_group, :leaderboard_data_load, :stop])

      metadata = %{source: :recalculate_leaderboard}
      Events.span_leaderboard_data_load(metadata, fn -> :done end)

      assert_receive {:telemetry_event, [:jalka2026, :query_group, :leaderboard_data_load, :start], _m, recv_meta}
      assert recv_meta.source == :recalculate_leaderboard

      assert_receive {:telemetry_event, [:jalka2026, :query_group, :leaderboard_data_load, :stop], stop_m, _meta}
      assert Map.has_key?(stop_m, :duration)
    end
  end
end

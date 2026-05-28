defmodule Jalka2026.Telemetry.QueryCounterTest do
  @moduledoc """
  Tests that verify Ecto query counts stay bounded across key operations.
  Catches N+1 regressions automatically via telemetry-based query counting.
  """
  use Jalka2026.DataCase

  import Jalka2026.FootballFixtures
  import Jalka2026.AccountsFixtures
  import Jalka2026.QueryCounter

  alias Jalka2026.Football
  alias Jalka2026.Leaderboard

  describe "prediction load query counts" do
    test "get_all_predictions_indexed uses a single query" do
      # Create some predictions to ensure table isn't empty
      user = user_fixture()
      match = finished_match_fixture()
      group_prediction_fixture(%{user: user, match: match, home_score: 1, away_score: 0})

      assert_max_queries(:predictions_indexed, 1, fn ->
        Football.get_all_predictions_indexed()
      end)
    end

    test "get_all_predictions_by_user uses a single query" do
      user = user_fixture()
      match = finished_match_fixture()
      group_prediction_fixture(%{user: user, match: match, home_score: 2, away_score: 1})

      assert_max_queries(:predictions_by_user, 1, fn ->
        Football.get_all_predictions_by_user()
      end)
    end

    test "get_all_playoff_predictions_indexed uses a single query" do
      user = user_fixture()
      team = team_fixture()
      playoff_prediction_fixture(%{user: user, team: team, phase: 16})

      assert_max_queries(:playoff_predictions_indexed, 1, fn ->
        Football.get_all_playoff_predictions_indexed()
      end)
    end

    test "prediction load scales O(1) regardless of user count" do
      # Create multiple users with predictions
      users = for _ <- 1..5, do: user_fixture()
      match = finished_match_fixture()

      for user <- users do
        group_prediction_fixture(%{user: user, match: match, home_score: 1, away_score: 0})
      end

      # Should still be a single query, not one per user
      assert_max_queries(:predictions_indexed_scale, 1, fn ->
        Football.get_all_predictions_indexed()
      end)
    end
  end

  describe "match listing query counts" do
    test "get_matches_by_group uses bounded queries (match + preloads)" do
      # One query for matches + preload queries for home_team and away_team
      # Ecto preloads run as separate queries, so expect up to 3
      assert_max_queries(:matches_by_group, 3, fn ->
        Football.get_matches_by_group("Alagrupp A")
      end)
    end

    test "get_finished_matches uses a single query" do
      assert_max_queries(:finished_matches, 1, fn ->
        Football.get_finished_matches()
      end)
    end

    test "get_matches uses bounded queries (match + preloads)" do
      # One query for matches + preload queries for home_team and away_team
      assert_max_queries(:all_matches, 3, fn ->
        Football.get_matches()
      end)
    end
  end

  describe "leaderboard calculation query counts" do
    test "full leaderboard recalculation uses bounded queries" do
      user = user_fixture()
      match = finished_match_fixture()
      group_prediction_fixture(%{user: user, match: match, home_score: 2, away_score: 1})

      # The leaderboard recalculation should use a bounded number of queries
      # regardless of user count. Key queries:
      # 1. finished_matches (1)
      # 2. playoff_results (1)
      # 3. users (1)
      # 4. all_predictions_indexed (1)
      # 5. all_predictions_by_user (1)
      # 6. all_playoff_predictions_indexed (1)
      # 7. streak upserts (batch, ~2-3 per user group)
      # 8. badge upserts (batch, ~2-3 per user group)
      # Allow generous headroom for streak/badge persistence
      assert_max_queries(:leaderboard_calc, 50, fn ->
        Leaderboard.recalc_leaderboard()
      end)
    end

    test "leaderboard data load phase uses at most 6 queries" do
      # The data-loading phase (before scoring) should be exactly:
      # 1. finished_matches
      # 2. playoff_results
      # 3. users
      # 4. all group predictions
      # 5. all group predictions (by user)
      # 6. all playoff predictions
      {_result, count} =
        count_queries(fn ->
          Football.get_finished_matches()
          Football.get_playoff_results()
          Jalka2026.Accounts.list_users()
          Football.get_all_predictions_indexed()
          Football.get_all_predictions_by_user()
          Football.get_all_playoff_predictions_indexed()
        end)

      assert count <= 6,
             "Leaderboard data load should use at most 6 queries, got #{count}"
    end

    test "query count does not scale with number of users" do
      # Create multiple users with predictions
      for _ <- 1..5 do
        user = user_fixture()
        match = finished_match_fixture()
        group_prediction_fixture(%{user: user, match: match, home_score: 1, away_score: 0})
      end

      {_result, count_5_users} =
        count_queries(fn ->
          Football.get_all_predictions_indexed()
          Football.get_all_predictions_by_user()
          Football.get_all_playoff_predictions_indexed()
        end)

      # Add more users
      for _ <- 1..5 do
        user = user_fixture()
        match = finished_match_fixture()
        group_prediction_fixture(%{user: user, match: match, home_score: 2, away_score: 0})
      end

      {_result, count_10_users} =
        count_queries(fn ->
          Football.get_all_predictions_indexed()
          Football.get_all_predictions_by_user()
          Football.get_all_playoff_predictions_indexed()
        end)

      # Query count should be identical regardless of user count
      assert count_5_users == count_10_users,
             "Query count should not scale with users: #{count_5_users} vs #{count_10_users}"
    end
  end

  describe "telemetry span events" do
    setup do
      handler_id = "test-span-#{System.unique_integer([:positive])}"

      events = [
        [:jalka2026, :query_group, :prediction_load, :start],
        [:jalka2026, :query_group, :prediction_load, :stop],
        [:jalka2026, :query_group, :match_listing, :start],
        [:jalka2026, :query_group, :match_listing, :stop],
        [:jalka2026, :query_group, :leaderboard_data_load, :start],
        [:jalka2026, :query_group, :leaderboard_data_load, :stop]
      ]

      :telemetry.attach_many(
        handler_id,
        events,
        fn name, measurements, metadata, _ ->
          send(self(), {:telemetry_event, name, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)
      :ok
    end

    test "prediction load emits telemetry span events" do
      Football.get_all_predictions_indexed()

      assert_receive {:telemetry_event, [:jalka2026, :query_group, :prediction_load, :start],
                      _measurements, %{source: :all_predictions_indexed}}

      assert_receive {:telemetry_event, [:jalka2026, :query_group, :prediction_load, :stop],
                      %{duration: _}, _metadata}
    end

    test "match listing emits telemetry span events" do
      Football.get_finished_matches()

      assert_receive {:telemetry_event, [:jalka2026, :query_group, :match_listing, :start],
                      _measurements, %{source: :finished_matches}}

      assert_receive {:telemetry_event, [:jalka2026, :query_group, :match_listing, :stop],
                      %{duration: _}, _metadata}
    end

    test "match listing by group includes group in metadata" do
      Football.get_matches_by_group("Alagrupp A")

      assert_receive {:telemetry_event, [:jalka2026, :query_group, :match_listing, :start],
                      _measurements, %{source: :matches_by_group, group: "Alagrupp A"}}
    end
  end
end

defmodule Jalka2026.QueryCounter do
  @moduledoc """
  Test helper for counting Ecto queries within telemetry spans.

  Attaches to Ecto's `[:jalka2026, :repo, :query]` telemetry event and counts
  queries executed during a given function. Use `assert_max_queries/3` in tests
  to catch N+1 regressions automatically.

  ## Usage

      import Jalka2026.QueryCounter

      test "leaderboard calculation uses bounded queries" do
        assert_max_queries(:leaderboard_calc, 10, fn ->
          Leaderboard.recalc_leaderboard()
        end)
      end
  """

  import ExUnit.Assertions

  @doc """
  Execute `fun` and assert that at most `max` Ecto queries are run.

  Returns the result of `fun`.

  `label` is an atom used for the telemetry handler ID and assertion messages
  (e.g. `:leaderboard_calc`, `:prediction_load`, `:match_listing`).

  ## Examples

      result = assert_max_queries(:leaderboard_calc, 10, fn ->
        Leaderboard.recalc_leaderboard()
      end)
  """
  def assert_max_queries(label, max, fun) when is_atom(label) and is_integer(max) do
    counter = :counters.new(1, [:atomics])
    handler_id = "query-counter-#{label}-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:jalka2026, :repo, :query],
      fn _event, _measurements, _metadata, _config ->
        :counters.add(counter, 1, 1)
      end,
      nil
    )

    try do
      result = fun.()
      query_count = :counters.get(counter, 1)

      assert query_count <= max,
             "Expected at most #{max} queries for #{label}, but got #{query_count}"

      result
    after
      :telemetry.detach(handler_id)
    end
  end

  @doc """
  Execute `fun` and return `{result, query_count}`.

  Useful when you want to inspect the count without asserting a maximum.

  ## Examples

      {result, count} = count_queries(fn ->
        Football.get_matches_by_group("A")
      end)
  """
  def count_queries(fun) do
    counter = :counters.new(1, [:atomics])
    handler_id = "query-counter-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:jalka2026, :repo, :query],
      fn _event, _measurements, _metadata, _config ->
        :counters.add(counter, 1, 1)
      end,
      nil
    )

    try do
      result = fun.()
      query_count = :counters.get(counter, 1)
      {result, query_count}
    after
      :telemetry.detach(handler_id)
    end
  end
end

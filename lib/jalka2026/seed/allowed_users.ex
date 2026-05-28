defmodule Jalka2026.Seed.AllowedUsers do
  @moduledoc """
  Seeds allowed users from JSON files.

  Provides `seed/1` for the primary user list and `seed_secondary/1`
  for the overflow file. Both are idempotent.
  """

  @behaviour Jalka2026.Seed.Repository

  require Logger
  alias Jalka2026.Seed.{Helpers, Parser, Runner}

  @impl true
  def seed(opts \\ []) do
    if Helpers.table_exists?("allowed_users") do
      count = Helpers.row_count("allowed_users")

      if count == 0 do
        path = Helpers.data_path("allowed_users.json", opts)
        competition_id = Helpers.competition_id(opts)
        has_cid = Helpers.column_exists?("allowed_users", "competition_id")

        names = Helpers.read_json!(path) |> Parser.parse_allowed_users()
        Runner.insert_allowed_users(names, competition_id, has_competition_id: has_cid)
      end
    end

    :ok
  end

  @doc """
  Seeds additional users from `allowed_users2.json`.

  Only inserts when the current count is below 990 (the full 2026 list).
  Uses `ON CONFLICT DO NOTHING` for safe re-entrancy.
  """
  def seed_secondary(opts \\ []) do
    if Helpers.table_exists?("allowed_users") do
      competition_id = Helpers.competition_id(opts)
      has_cid = Helpers.column_exists?("allowed_users", "competition_id")
      current_count = secondary_count(competition_id, has_cid)

      if current_count < 990 do
        do_seed_secondary(opts, competition_id, has_cid)
      end
    end

    :ok
  end

  defp secondary_count(competition_id, true) do
    %{rows: [[c]]} =
      Helpers.query!(
        "SELECT COUNT(id) FROM allowed_users WHERE competition_id = $1",
        [competition_id]
      )

    c
  end

  defp secondary_count(_competition_id, false), do: Helpers.row_count("allowed_users")

  defp do_seed_secondary(opts, competition_id, has_cid) do
    Logger.info("Adding secondary seed data for 2026 tournament...")
    path = Helpers.data_path("allowed_users2.json", opts)

    if File.exists?(path) do
      names = Helpers.read_json!(path) |> Parser.parse_allowed_users()

      Runner.insert_allowed_users(names, competition_id,
        has_competition_id: has_cid,
        on_conflict: :nothing
      )
    end
  end
end

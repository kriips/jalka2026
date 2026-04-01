defmodule Jalka2026.Seed.Teams do
  @moduledoc """
  Seeds teams from `teams.json`, deriving group assignments from matches data.

  Idempotent — skips when teams already exist in the database.
  """

  @behaviour Jalka2026.Seed.Repository

  alias Jalka2026.Seed.{Helpers, Parser, Runner}

  @impl true
  def seed(opts \\ []) do
    if Helpers.table_exists?("teams") && Helpers.row_count("teams") == 0 do
      raw_matches = load_matches_raw(opts)
      team_groups = Parser.build_team_groups(raw_matches)

      path = Helpers.data_path("teams.json", opts)
      raw_teams = Helpers.read_json!(path)
      teams = Parser.parse_teams(raw_teams, team_groups)

      has_cid = Helpers.column_exists?("teams", "competition_id")
      competition_id = Helpers.competition_id(opts)
      Runner.insert_teams(teams, competition_id, has_competition_id: has_cid)
    end

    :ok
  end

  @doc """
  Build a map of `team_id -> group_letter` from matches JSON.

  This is also used by `Jalka2026.Seed.Matches` to avoid parsing the file twice.
  """
  def build_team_groups(opts \\ []) do
    load_matches_raw(opts) |> Parser.build_team_groups()
  end

  @doc """
  Load raw matches list from JSON (handles both array and object formats).
  """
  def load_matches(opts \\ []) do
    load_matches_raw(opts)
  end

  # -- private ----------------------------------------------------------------

  defp load_matches_raw(opts) do
    path = Helpers.data_path("matches.json", opts)
    Helpers.read_json!(path) |> Parser.normalize_matches()
  end
end

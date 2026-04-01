defmodule Jalka2026.Seed.Matches do
  @moduledoc """
  Seeds group-stage matches from `matches.json`.

  Idempotent — skips when matches already exist in the database.
  """

  @behaviour Jalka2026.Seed.Repository

  alias Jalka2026.Seed.{Helpers, Parser, Runner, Teams}

  @impl true
  def seed(opts \\ []) do
    if Helpers.table_exists?("matches") && Helpers.row_count("matches") == 0 do
      raw_matches = Teams.load_matches(opts)
      matches = Parser.parse_group_matches(raw_matches)

      has_cid = Helpers.column_exists?("matches", "competition_id")
      competition_id = Helpers.competition_id(opts)
      Runner.insert_matches(matches, competition_id, has_competition_id: has_cid)
    end

    :ok
  end
end

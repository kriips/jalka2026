defmodule Jalka2026.Seed.TournamentStandings do
  @moduledoc """
  Seeds historical tournament standings from `tournament_standings.json`.

  Idempotent — skips when standings already exist or the table schema doesn't match.
  """

  @behaviour Jalka2026.Seed.Repository

  require Logger
  alias Jalka2026.Seed.{Helpers, Parser, Runner}

  @impl true
  def seed(opts \\ []) do
    if Helpers.table_exists?("tournament_standings") &&
         Helpers.column_exists?("tournament_standings", "tournament_id") &&
         Helpers.row_count("tournament_standings") == 0 do
      path = Helpers.data_path("tournament_standings.json", opts)

      if File.exists?(path) do
        Logger.info("Seeding tournament standings from JSON...")
        standings = Helpers.read_json!(path) |> Parser.parse_tournament_standings()
        Runner.insert_tournament_standings(standings)
        Logger.info("Tournament standings seeded successfully!")
      end
    end

    :ok
  end
end

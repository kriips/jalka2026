defmodule Jalka2026.Seed.HistoricalMatches do
  @moduledoc """
  Seeds historical FIFA match data from `historical_matches.json`.

  Idempotent — skips when historical matches already exist in the database.
  """

  @behaviour Jalka2026.Seed.Repository

  require Logger
  alias Jalka2026.Seed.{Helpers, Parser, Runner}

  @impl true
  def seed(opts \\ []) do
    if Helpers.table_exists?("historical_matches") && Helpers.row_count("historical_matches") == 0 do
      path = Helpers.data_path("historical_matches.json", opts)

      if File.exists?(path) do
        Logger.info("Seeding historical matches from JSON...")
        matches = Helpers.read_json!(path) |> Parser.parse_historical_matches()
        Runner.insert_historical_matches(matches)
        Logger.info("Historical matches seeded successfully!")
      end
    end

    :ok
  end
end

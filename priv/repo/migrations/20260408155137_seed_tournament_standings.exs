defmodule Jalka2026.Repo.Migrations.SeedTournamentStandings do
  use Ecto.Migration

  def up do
    # The tournament_standings table was created in a migration that runs AFTER
    # the initial seed migration (20221108144403_run_seeds), so the seed data
    # was never inserted. Seed it now.
    if Jalka2026.Seed.Helpers.table_exists?("tournament_standings") &&
         Jalka2026.Seed.Helpers.row_count("tournament_standings") == 0 do
      Jalka2026.Seed.TournamentStandings.seed()
    end
  end

  def down do
    :ok
  end
end

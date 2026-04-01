defmodule Jalka2026.Seed do
  @moduledoc """
  Orchestrates seed data loading by delegating to individual repository modules.

  Each repository implements `Jalka2026.Seed.Repository` and is independently
  callable and idempotent.

  ## Repositories

    * `Jalka2026.Seed.Competition` – default competition record
    * `Jalka2026.Seed.AllowedUsers` – allowed user lists
    * `Jalka2026.Seed.Teams` – teams with group assignments
    * `Jalka2026.Seed.Matches` – group-stage matches
    * `Jalka2026.Seed.HistoricalMatches` – historical FIFA match data
    * `Jalka2026.Seed.TournamentStandings` – historical tournament standings
  """

  alias Jalka2026.Seed

  @doc """
  Run all primary seeds in dependency order.

  Called from migration `20221108144403_run_seeds.exs`.
  """
  def seed do
    Seed.Competition.seed()
    Seed.AllowedUsers.seed()
    Seed.Teams.seed()
    Seed.Matches.seed()
    Seed.HistoricalMatches.seed()
    Seed.TournamentStandings.seed()
  end

  @doc """
  Run secondary seeds (overflow allowed users).

  Called from migration `20221116144403_run_seeds_2.exs`.
  """
  def seed2 do
    Seed.AllowedUsers.seed_secondary()
  end
end

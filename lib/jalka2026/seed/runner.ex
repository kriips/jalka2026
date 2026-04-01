defmodule Jalka2026.Seed.Runner do
  @moduledoc """
  Side-effectful database writes for seed data.

  All functions in this module accept pre-parsed data (output of
  `Jalka2026.Seed.Parser`) and insert it into the database. They handle
  schema-awareness (e.g. whether `competition_id` column exists) and
  idempotency guards.

  ## Usage

      names = Jalka2026.Seed.Parser.parse_allowed_users(raw_json)
      Jalka2026.Seed.Runner.insert_allowed_users(names, competition_id, has_competition_id: true)
  """

  require Logger
  alias Jalka2026.Seed.Helpers

  # -------------------------------------------------------------------
  # Competition
  # -------------------------------------------------------------------

  @doc """
  Insert the default competition if it doesn't exist.
  """
  def insert_competition(attrs, competition_id) do
    if Helpers.table_exists?("competitions") && Code.ensure_compiled(Jalka2026.Football.Competition) do
      case Jalka2026.Repo.get(Jalka2026.Football.Competition, competition_id) do
        nil ->
          %Jalka2026.Football.Competition{}
          |> Jalka2026.Football.Competition.changeset(attrs)
          |> Jalka2026.Repo.insert!()

          Logger.info("Created default competition: #{competition_id}")

        _ ->
          :ok
      end
    end

    :ok
  end

  # -------------------------------------------------------------------
  # Allowed users
  # -------------------------------------------------------------------

  @doc """
  Insert a list of user names into `allowed_users`.

  Options:
    * `:has_competition_id` – whether the table has a `competition_id` column
    * `:on_conflict` – `:nothing` to use `ON CONFLICT DO NOTHING` (default `:raise`)
  """
  def insert_allowed_users(names, competition_id, opts \\ []) do
    has_cid = Keyword.get(opts, :has_competition_id, false)
    on_conflict = Keyword.get(opts, :on_conflict, :raise)
    conflict_clause = if on_conflict == :nothing, do: " ON CONFLICT DO NOTHING", else: ""

    Enum.each(names, fn name ->
      now = Helpers.now()

      if has_cid do
        Helpers.query!(
          "INSERT INTO allowed_users (name, competition_id, inserted_at, updated_at) VALUES ($1, $2, $3, $4)#{conflict_clause}",
          [name, competition_id, now, now]
        )
      else
        Helpers.query!(
          "INSERT INTO allowed_users (name, inserted_at, updated_at) VALUES ($1, $2, $3)#{conflict_clause}",
          [name, now, now]
        )
      end
    end)
  end

  # -------------------------------------------------------------------
  # Teams
  # -------------------------------------------------------------------

  @doc """
  Insert parsed team maps into `teams`.

  Each map must have keys: `:id`, `:name`, `:code`, `:flag`, `:group`.
  """
  def insert_teams(teams, competition_id, opts \\ []) do
    has_cid = Keyword.get(opts, :has_competition_id, false)

    Enum.each(teams, fn team ->
      now = Helpers.now()

      if has_cid do
        Helpers.query!(
          "INSERT INTO teams (id, name, code, flag, \"group\", competition_id, inserted_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
          [team.id, team.name, team.code, team.flag, team.group, competition_id, now, now]
        )
      else
        Helpers.query!(
          "INSERT INTO teams (id, name, code, flag, \"group\", inserted_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7)",
          [team.id, team.name, team.code, team.flag, team.group, now, now]
        )
      end
    end)
  end

  # -------------------------------------------------------------------
  # Group-stage matches
  # -------------------------------------------------------------------

  @doc """
  Insert parsed group-stage match maps into `matches`.

  Each map must have keys: `:group`, `:home_team_id`, `:away_team_id`, `:date`.
  """
  def insert_matches(matches, competition_id, opts \\ []) do
    has_cid = Keyword.get(opts, :has_competition_id, false)

    Enum.each(matches, fn match ->
      now = Helpers.now()

      if has_cid do
        Helpers.query!(
          "INSERT INTO matches (\"group\", home_team_id, away_team_id, date, competition_id, finished, inserted_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
          [match.group, match.home_team_id, match.away_team_id, match.date, competition_id, false, now, now]
        )
      else
        Helpers.query!(
          "INSERT INTO matches (\"group\", home_team_id, away_team_id, date, finished, inserted_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7)",
          [match.group, match.home_team_id, match.away_team_id, match.date, false, now, now]
        )
      end
    end)
  end

  # -------------------------------------------------------------------
  # Historical matches
  # -------------------------------------------------------------------

  @doc """
  Insert parsed historical match maps into `historical_matches`.
  """
  def insert_historical_matches(matches) do
    Enum.each(matches, fn m ->
      now = Helpers.now()

      Helpers.query!(
        "INSERT INTO historical_matches (home_team_code, away_team_code, home_team_name, away_team_name, home_score, away_score, date, competition, stage, venue, is_world_cup, inserted_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)",
        [
          m.home_team_code,
          m.away_team_code,
          m.home_team_name,
          m.away_team_name,
          m.home_score,
          m.away_score,
          m.date,
          m.competition,
          m.stage,
          m.venue,
          m.is_world_cup,
          now,
          now
        ]
      )
    end)
  end

  # -------------------------------------------------------------------
  # Tournament standings
  # -------------------------------------------------------------------

  @doc """
  Insert parsed tournament standing maps into `tournament_standings`.
  """
  def insert_tournament_standings(standings) do
    Enum.each(standings, fn s ->
      now = Helpers.now()

      Helpers.query!(
        "INSERT INTO tournament_standings (tournament_id, tournament_name, position, team_code, team_name, inserted_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7)",
        [
          s.tournament_id,
          s.tournament_name,
          s.position,
          s.team_code,
          s.team_name,
          now,
          now
        ]
      )
    end)
  end
end

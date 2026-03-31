defmodule Jalka2026.Seed do
  require Logger

  # Map team area codes to ISO 2-letter country codes for local flag files
  # The flags are stored in priv/static/images/flags/{iso_code}.svg
  @team_area_to_flag %{
    # World Cup 2026 participants - mapped from area.code to ISO 2-letter
    "URY" => "uy",
    "DEU" => "de",
    "ESP" => "es",
    "PRY" => "py",
    "ARG" => "ar",
    "GHA" => "gh",
    "BRA" => "br",
    "POR" => "pt",
    "JPN" => "jp",
    "MEX" => "mx",
    "ENG" => "gb-eng",
    "USA" => "us",
    "KOR" => "kr",
    "FRA" => "fr",
    "RSA" => "za",
    "ALG" => "dz",
    "AUS" => "au",
    "NZL" => "nz",
    "CHE" => "ch",
    "ECU" => "ec",
    "HRV" => "hr",
    "KSA" => "sa",
    "TUN" => "tn",
    "SEN" => "sn",
    "BEL" => "be",
    "MAR" => "ma",
    "AUT" => "at",
    "COL" => "co",
    "EGY" => "eg",
    "CAN" => "ca",
    "HTI" => "ht",
    "IRN" => "ir",
    "PAN" => "pa",
    "CPV" => "cv",
    "CIV" => "ci",
    "QAT" => "qa",
    "JOR" => "jo",
    "UZB" => "uz",
    "NLD" => "nl",
    "NOR" => "no",
    "SCO" => "gb-sct",
    "ANT" => "cw"
  }

  # Get the local flag path for a team based on area code
  defp get_local_flag_path(area_code) when is_binary(area_code) do
    case Map.get(@team_area_to_flag, area_code) do
      nil -> nil
      iso_code -> "/images/flags/#{iso_code}.svg"
    end
  end

  defp get_local_flag_path(_), do: nil

  # Check if a column exists on a table by querying the information_schema
  defp column_exists?(table, column) do
    result =
      Ecto.Adapters.SQL.query!(
        Jalka2026.Repo,
        "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = $1 AND column_name = $2",
        [table, column]
      )

    [[count]] = result.rows
    count > 0
  end

  # Check if a table exists
  defp table_exists?(table) do
    result =
      Ecto.Adapters.SQL.query!(
        Jalka2026.Repo,
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = $1 AND table_schema = 'public'",
        [table]
      )

    [[count]] = result.rows
    count > 0
  end

  def seed do
    prefix =
      case Application.get_env(:jalka2026, :environment) do
        :prod -> "/app/lib/jalka2026-0.1.0"
        _ -> Mix.Project.app_path()
      end

    competition_id = Jalka2026.Competitions.current_id()
    has_competition_id = column_exists?("allowed_users", "competition_id")

    # Ensure the default competition exists (only if the competitions table exists)
    if table_exists?("competitions") && Code.ensure_compiled(Jalka2026.Football.Competition) do
      case Jalka2026.Repo.get(Jalka2026.Football.Competition, competition_id) do
        nil ->
          %Jalka2026.Football.Competition{}
          |> Jalka2026.Football.Competition.changeset(%{
            id: "wc-2026",
            name: "FIFA World Cup 2026",
            short_name: "MM 2026",
            type: "world_cup",
            year: 2026,
            start_date: ~D[2026-06-11],
            end_date: ~D[2026-07-19],
            prediction_deadline: ~U[2026-06-11 19:00:00Z],
            is_active: true
          })
          |> Jalka2026.Repo.insert!()
          Logger.info("Created default competition: wc-2026")

        _ ->
          :ok
      end
    end

    if table_exists?("allowed_users") do
      %{rows: [[count]]} =
        Ecto.Adapters.SQL.query!(Jalka2026.Repo, "SELECT COUNT(id) FROM allowed_users", [])

      if count == 0 do
        Enum.each(
          Jason.decode!(File.read!("#{prefix}/priv/repo/data/allowed_users.json")),
          fn attrs ->
            now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

            if has_competition_id do
              Ecto.Adapters.SQL.query!(
                Jalka2026.Repo,
                "INSERT INTO allowed_users (name, competition_id, inserted_at, updated_at) VALUES ($1, $2, $3, $4)",
                [attrs["name"], competition_id, now, now]
              )
            else
              Ecto.Adapters.SQL.query!(
                Jalka2026.Repo,
                "INSERT INTO allowed_users (name, inserted_at, updated_at) VALUES ($1, $2, $3)",
                [attrs["name"], now, now]
              )
            end
          end
        )
      end
    end

    # Load matches first to derive team groups (new format doesn't have group in teams.json)
    matches_data = Jason.decode!(File.read!("#{prefix}/priv/repo/data/matches.json"))

    matches =
      if is_list(matches_data), do: matches_data, else: Map.get(matches_data, "matches", [])

    # Build a map of team_id -> group from matches (GROUP_A -> A, GROUP_B -> B, etc.)
    team_groups =
      matches
      |> Enum.filter(&(&1["stage"] == "GROUP_STAGE"))
      |> Enum.flat_map(fn match ->
        group = match["group"] |> String.replace("GROUP_", "")

        [
          {match["homeTeam"]["id"], group},
          {match["awayTeam"]["id"], group}
        ]
      end)
      |> Enum.reject(fn {id, _} -> is_nil(id) end)
      |> Enum.into(%{})

    has_teams_competition_id = column_exists?("teams", "competition_id")

    if table_exists?("teams") do
      %{rows: [[teams_count]]} =
        Ecto.Adapters.SQL.query!(Jalka2026.Repo, "SELECT COUNT(id) FROM teams", [])

      if teams_count == 0 do
        teams_data = Jason.decode!(File.read!("#{prefix}/priv/repo/data/teams.json"))
        # Handle both old format (flat array) and new format (object with "teams" key)
        teams = if is_list(teams_data), do: teams_data, else: Map.get(teams_data, "teams", [])

        Enum.each(
          teams,
          fn attrs ->
            team_id = Map.get(attrs, "id")
            # Get group from team data (old format) or derive from matches (new format)
            group = Map.get(attrs, "group") || Map.get(team_groups, team_id)
            # Use tla, or shortName, or first 3 chars of name as fallback for code
            code =
              Map.get(attrs, "tla") || Map.get(attrs, "shortName") ||
                String.slice(Map.get(attrs, "name", "UNK"), 0, 3) |> String.upcase()

            # Get local flag path from area code, fall back to external crest URL
            area_code = get_in(attrs, ["area", "code"])
            flag = get_local_flag_path(area_code) || Map.get(attrs, "crest")

            if group do
              now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

              if has_teams_competition_id do
                Ecto.Adapters.SQL.query!(
                  Jalka2026.Repo,
                  "INSERT INTO teams (id, name, code, flag, \"group\", competition_id, inserted_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
                  [team_id, Map.get(attrs, "name"), code, flag, group, "wc-2026", now, now]
                )
              else
                Ecto.Adapters.SQL.query!(
                  Jalka2026.Repo,
                  "INSERT INTO teams (id, name, code, flag, \"group\", inserted_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7)",
                  [team_id, Map.get(attrs, "name"), code, flag, group, now, now]
                )
              end
            else
              Logger.warning(
                "Skipping team #{team_id} (#{Map.get(attrs, "name")}) - no group found"
              )
            end
          end
        )
      end
    end

    has_matches_competition_id = column_exists?("matches", "competition_id")

    if table_exists?("matches") do
      %{rows: [[matches_count]]} =
        Ecto.Adapters.SQL.query!(Jalka2026.Repo, "SELECT COUNT(id) FROM matches", [])

      if matches_count == 0 do
        Enum.each(
          matches,
          fn attrs ->
            home_team_id = Kernel.get_in(attrs, ["homeTeam", "id"])
            away_team_id = Kernel.get_in(attrs, ["awayTeam", "id"])

            if Map.get(attrs, "stage") == "GROUP_STAGE" && home_team_id && away_team_id do
              # Transform GROUP_A -> Alagrupp A, GROUP_B -> Alagrupp B, etc.
              group_letter = Map.get(attrs, "group") |> String.replace("GROUP_", "")
              group = "Alagrupp #{group_letter}"
              now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
              date = Map.get(attrs, "utcDate")

              parsed_date =
                case date do
                  nil -> nil
                  d when is_binary(d) -> NaiveDateTime.from_iso8601!(d)
                  d -> d
                end

              if has_matches_competition_id do
                Ecto.Adapters.SQL.query!(
                  Jalka2026.Repo,
                  "INSERT INTO matches (\"group\", home_team_id, away_team_id, date, competition_id, finished, inserted_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
                  [group, home_team_id, away_team_id, parsed_date, "wc-2026", false, now, now]
                )
              else
                Ecto.Adapters.SQL.query!(
                  Jalka2026.Repo,
                  "INSERT INTO matches (\"group\", home_team_id, away_team_id, date, finished, inserted_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7)",
                  [group, home_team_id, away_team_id, parsed_date, false, now, now]
                )
              end
            end
          end
        )
      end
    end

    # Seed historical matches from JSON file
    if table_exists?("historical_matches") do
      %{rows: [[hist_count]]} =
        Ecto.Adapters.SQL.query!(Jalka2026.Repo, "SELECT COUNT(id) FROM historical_matches", [])

      if hist_count == 0 do
        historical_file = "#{prefix}/priv/repo/data/historical_matches.json"

        if File.exists?(historical_file) do
          Logger.info("Seeding historical matches from JSON...")

          now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

          Enum.each(
            Jason.decode!(File.read!(historical_file)),
            fn attrs ->
              date =
                case Map.get(attrs, "date") do
                  nil -> nil
                  d when is_binary(d) -> Date.from_iso8601!(d)
                  d -> d
                end

              Ecto.Adapters.SQL.query!(
                Jalka2026.Repo,
                "INSERT INTO historical_matches (home_team_code, away_team_code, home_team_name, away_team_name, home_score, away_score, date, competition, stage, venue, is_world_cup, inserted_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)",
                [
                  Map.get(attrs, "home_team_code"),
                  Map.get(attrs, "away_team_code"),
                  Map.get(attrs, "home_team_name"),
                  Map.get(attrs, "away_team_name"),
                  Map.get(attrs, "home_score"),
                  Map.get(attrs, "away_score"),
                  date,
                  Map.get(attrs, "competition"),
                  Map.get(attrs, "stage"),
                  Map.get(attrs, "venue"),
                  Map.get(attrs, "is_world_cup", false),
                  now,
                  now
                ]
              )
            end
          )

          Logger.info("Historical matches seeded successfully!")
        end
      end
    end

    # Seed tournament standings from JSON file
    # Check both table existence and that the expected columns exist (the table may have
    # been created with a different schema in a previous migration run)
    if table_exists?("tournament_standings") && column_exists?("tournament_standings", "tournament_id") do
      %{rows: [[standings_count]]} =
        Ecto.Adapters.SQL.query!(Jalka2026.Repo, "SELECT COUNT(id) FROM tournament_standings", [])

      if standings_count == 0 do
        standings_file = "#{prefix}/priv/repo/data/tournament_standings.json"

        if File.exists?(standings_file) do
          Logger.info("Seeding tournament standings from JSON...")

          now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

          Enum.each(
            Jason.decode!(File.read!(standings_file)),
            fn attrs ->
              Ecto.Adapters.SQL.query!(
                Jalka2026.Repo,
                "INSERT INTO tournament_standings (tournament_id, tournament_name, position, team_code, team_name, inserted_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7)",
                [
                  Map.get(attrs, "tournament_id"),
                  Map.get(attrs, "tournament_name"),
                  Map.get(attrs, "position"),
                  Map.get(attrs, "team_code"),
                  Map.get(attrs, "team_name"),
                  now,
                  now
                ]
              )
            end
          )

          Logger.info("Tournament standings seeded successfully!")
        end
      end
    end
  end

  def seed2 do
    prefix =
      case Application.get_env(:jalka2026, :environment) do
        :prod -> "/app/lib/jalka2026-0.1.0"
        _ -> Mix.Project.app_path()
      end

    competition_id = Jalka2026.Competitions.current_id()
    has_competition_id = column_exists?("allowed_users", "competition_id")

    # For 2026 tournament: Load any additional users from allowed_users2.json
    # The main allowed_users.json now has 990 users for the 2026 tournament
    if table_exists?("allowed_users") do
      current_count =
        if has_competition_id do
          %{rows: [[count]]} =
            Ecto.Adapters.SQL.query!(
              Jalka2026.Repo,
              "SELECT COUNT(id) FROM allowed_users WHERE competition_id = $1",
              [competition_id]
            )

          count
        else
          %{rows: [[count]]} =
            Ecto.Adapters.SQL.query!(Jalka2026.Repo, "SELECT COUNT(id) FROM allowed_users", [])

          count
        end

      # Only add secondary users if count is below expected 990 (2026 tournament list)
      if current_count < 990 do
        Logger.info("Adding secondary seed data for 2026 tournament...")
        secondary_file = "#{prefix}/priv/repo/data/allowed_users2.json"

        if File.exists?(secondary_file) do
          Enum.each(
            Jason.decode!(File.read!(secondary_file)),
            fn attrs ->
              now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

              if has_competition_id do
                Ecto.Adapters.SQL.query!(
                  Jalka2026.Repo,
                  "INSERT INTO allowed_users (name, competition_id, inserted_at, updated_at) VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING",
                  [attrs["name"], competition_id, now, now]
                )
              else
                Ecto.Adapters.SQL.query!(
                  Jalka2026.Repo,
                  "INSERT INTO allowed_users (name, inserted_at, updated_at) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING",
                  [attrs["name"], now, now]
                )
              end
            end
          )
        end
      end
    end
  end
end

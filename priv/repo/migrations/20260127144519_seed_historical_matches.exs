defmodule Jalka2026.Repo.Migrations.SeedHistoricalMatches do
  use Ecto.Migration

  def up do
    # Skip if historical matches were already seeded (e.g., by Seed.seed/0)
    %{rows: [[count]]} =
      repo().query!("SELECT COUNT(*) FROM historical_matches", [])

    if count > 0 do
      :ok
    else
      historical_matches =
        Path.join(:code.priv_dir(:jalka2026), "repo/data/historical_matches.json")
        |> File.read!()
        |> Jason.decode!()

      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      for match <- historical_matches do
        execute("""
        INSERT INTO historical_matches (
          home_team_code, away_team_code, home_team_name, away_team_name,
          home_score, away_score, date, competition, stage, venue, is_world_cup,
          inserted_at, updated_at
        ) VALUES (
          '#{match["home_team_code"]}',
          '#{match["away_team_code"]}',
          '#{String.replace(match["home_team_name"], "'", "''")}',
          '#{String.replace(match["away_team_name"], "'", "''")}',
          #{match["home_score"]},
          #{match["away_score"]},
          '#{match["date"]}',
          '#{String.replace(match["competition"], "'", "''")}',
          #{if match["stage"], do: "'#{String.replace(match["stage"], "'", "''")}'", else: "NULL"},
          #{if match["venue"], do: "'#{String.replace(match["venue"], "'", "''")}'", else: "NULL"},
          #{match["is_world_cup"]},
          '#{now}',
          '#{now}'
        )
        """)
      end
    end
  end

  def down do
    execute("DELETE FROM historical_matches")
  end
end

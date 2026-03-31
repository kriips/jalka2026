defmodule Jalka2026.Repo.Migrations.CreateTournamentStandings do
  use Ecto.Migration

  def up do
    # Drop the table if it exists with wrong schema (from a previous migration run)
    # The expected schema has tournament_id, but an old version had team_id
    result =
      repo().query!(
        "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'tournament_standings' AND column_name = 'tournament_id'",
        []
      )

    [[has_correct_schema]] = result.rows

    if has_correct_schema == 0 do
      execute("DROP TABLE IF EXISTS tournament_standings")
    end

    create_if_not_exists table(:tournament_standings) do
      add :tournament_id, :string, null: false
      add :tournament_name, :string, null: false
      add :position, :integer, null: false
      add :team_code, :string, null: false
      add :team_name, :string, null: false

      timestamps()
    end

    create_if_not_exists index(:tournament_standings, [:team_code])
    create_if_not_exists index(:tournament_standings, [:tournament_id])
    create_if_not_exists unique_index(:tournament_standings, [:tournament_id, :position])
  end

  def down do
    drop_if_exists table(:tournament_standings)
  end
end

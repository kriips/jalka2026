defmodule Jalka2026.Repo.Migrations.CreateCompetitions do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:competitions, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :short_name, :string, null: false
      add :type, :string, null: false
      add :year, :integer, null: false
      add :start_date, :date
      add :end_date, :date
      add :prediction_deadline, :utc_datetime
      add :is_active, :boolean, default: false
      add :config, :map, default: %{}

      timestamps()
    end

    create_if_not_exists unique_index(:competitions, [:id])
    create_if_not_exists index(:competitions, [:is_active])
    create_if_not_exists index(:competitions, [:year])

    # Seed the initial competition for World Cup 2026
    # IMPORTANT: This must happen BEFORE adding FK columns with default "wc-2026"
    # to other tables, otherwise existing rows will violate the FK constraint.
    execute(
      """
      INSERT INTO competitions (id, name, short_name, type, year, start_date, end_date, prediction_deadline, is_active, config, inserted_at, updated_at)
      VALUES ('wc-2026', 'FIFA World Cup 2026', 'MM 2026', 'world_cup', 2026, '2026-06-11', '2026-07-19', '2026-06-11 19:00:00', true, '{}', NOW(), NOW())
      ON CONFLICT (id) DO NOTHING
      """,
      """
      DELETE FROM competitions WHERE id = 'wc-2026'
      """
    )

    # Add competition_id to teams table
    alter table(:teams) do
      add_if_not_exists :competition_id, references(:competitions, type: :string, on_delete: :restrict),
        default: "wc-2026"
    end

    create_if_not_exists index(:teams, [:competition_id])

    # Add competition_id to matches table
    alter table(:matches) do
      add_if_not_exists :competition_id, references(:competitions, type: :string, on_delete: :restrict),
        default: "wc-2026"
    end

    create_if_not_exists index(:matches, [:competition_id])

    # Add competition_id to playoff_results table
    alter table(:playoff_results) do
      add_if_not_exists :competition_id, references(:competitions, type: :string, on_delete: :restrict),
        default: "wc-2026"
    end

    create_if_not_exists index(:playoff_results, [:competition_id])

    # Add competition_id to bracket_results table
    alter table(:bracket_results) do
      add_if_not_exists :competition_id, references(:competitions, type: :string, on_delete: :restrict),
        default: "wc-2026"
    end

    create_if_not_exists index(:bracket_results, [:competition_id])

    # Update existing data to reference the new competition
    execute(
      "UPDATE teams SET competition_id = 'wc-2026' WHERE competition_id IS NULL OR competition_id = 'wc-2026'",
      "SELECT 1"
    )

    execute(
      "UPDATE matches SET competition_id = 'wc-2026' WHERE competition_id IS NULL OR competition_id = 'wc-2026'",
      "SELECT 1"
    )

    execute(
      "UPDATE playoff_results SET competition_id = 'wc-2026' WHERE competition_id IS NULL OR competition_id = 'wc-2026'",
      "SELECT 1"
    )

    execute(
      "UPDATE bracket_results SET competition_id = 'wc-2026' WHERE competition_id IS NULL OR competition_id = 'wc-2026'",
      "SELECT 1"
    )

    # Migrate existing users and allowed_users from old "eys" competition_id to "wc-2026"
    execute(
      "UPDATE users SET competition_id = 'wc-2026' WHERE competition_id = 'eys'",
      "UPDATE users SET competition_id = 'eys' WHERE competition_id = 'wc-2026'"
    )

    execute(
      "UPDATE allowed_users SET competition_id = 'wc-2026' WHERE competition_id = 'eys'",
      "UPDATE allowed_users SET competition_id = 'eys' WHERE competition_id = 'wc-2026'"
    )

    # Update the column defaults for users and allowed_users
    execute(
      "ALTER TABLE users ALTER COLUMN competition_id SET DEFAULT 'wc-2026'",
      "ALTER TABLE users ALTER COLUMN competition_id SET DEFAULT 'eys'"
    )

    execute(
      "ALTER TABLE allowed_users ALTER COLUMN competition_id SET DEFAULT 'wc-2026'",
      "ALTER TABLE allowed_users ALTER COLUMN competition_id SET DEFAULT 'eys'"
    )
  end
end

defmodule Jalka2026.Repo.Migrations.AddPlayoffBracketVersionToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add_if_not_exists(:playoff_bracket_version, :string)
    end

    execute("""
    UPDATE users
    SET playoff_bracket_version =
      CASE
        WHEN EXISTS (
          SELECT 1
          FROM bracket_predictions
          WHERE bracket_predictions.user_id = users.id
        )
        OR EXISTS (
          SELECT 1
          FROM playoff_predictions
          WHERE playoff_predictions.user_id = users.id
        )
        THEN 'legacy_2026'
        ELSE 'official_2026'
      END
    WHERE playoff_bracket_version IS NULL
    """)

    execute("ALTER TABLE users ALTER COLUMN playoff_bracket_version SET DEFAULT 'official_2026'")
    execute("ALTER TABLE users ALTER COLUMN playoff_bracket_version SET NOT NULL")
  end

  def down do
    alter table(:users) do
      remove_if_exists(:playoff_bracket_version, :string)
    end
  end
end

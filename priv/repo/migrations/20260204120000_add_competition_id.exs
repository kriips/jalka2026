defmodule Jalka2026.Repo.Migrations.AddCompetitionId do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add_if_not_exists :competition_id, :string, default: "eys"
    end

    alter table(:allowed_users) do
      add_if_not_exists :competition_id, :string, default: "eys"
    end

    # Index for efficient queries scoped by competition
    create_if_not_exists index(:users, [:competition_id])
    create_if_not_exists index(:allowed_users, [:competition_id])

    # Remove duplicate allowed_users before creating unique index
    execute("""
    DELETE FROM allowed_users
    WHERE id NOT IN (
      SELECT MIN(id)
      FROM allowed_users
      GROUP BY name, competition_id
    )
    """)

    # Remove duplicate users before creating unique index
    execute("""
    DELETE FROM users
    WHERE id NOT IN (
      SELECT MIN(id)
      FROM users
      GROUP BY name, competition_id
    )
    """)

    # Update unique constraints to be scoped by competition
    # This allows the same user name to exist in different competitions
    drop_if_exists unique_index(:allowed_users, [:name])
    create_if_not_exists unique_index(:allowed_users, [:name, :competition_id])

    drop_if_exists unique_index(:users, [:name])
    create_if_not_exists unique_index(:users, [:name, :competition_id])
  end

  def down do
    drop_if_exists unique_index(:users, [:name, :competition_id])
    drop_if_exists unique_index(:allowed_users, [:name, :competition_id])
    drop_if_exists index(:allowed_users, [:competition_id])
    drop_if_exists index(:users, [:competition_id])

    alter table(:allowed_users) do
      remove_if_exists :competition_id, :string
    end

    alter table(:users) do
      remove_if_exists :competition_id, :string
    end
  end
end

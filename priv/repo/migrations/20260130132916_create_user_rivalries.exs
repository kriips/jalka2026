defmodule Jalka2026.Repo.Migrations.CreateUserRivalries do
  use Ecto.Migration

  def up do
    # Drop table if it exists with wrong schema (e.g., rival_user_id instead of rival_id)
    result =
      repo().query!(
        "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'user_rivalries' AND column_name = 'rival_id'",
        []
      )

    [[has_correct_schema]] = result.rows

    if has_correct_schema == 0 do
      execute("DROP TABLE IF EXISTS user_rivalries")
    end

    create_if_not_exists table(:user_rivalries) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :rival_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, default: "active"
      add :notifications_enabled, :boolean, default: true

      timestamps()
    end

    create_if_not_exists unique_index(:user_rivalries, [:user_id, :rival_id])
    create_if_not_exists index(:user_rivalries, [:user_id])
    create_if_not_exists index(:user_rivalries, [:rival_id])
  end

  def down do
    drop_if_exists table(:user_rivalries)
  end
end

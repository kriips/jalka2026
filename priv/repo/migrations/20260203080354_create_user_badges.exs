defmodule Jalka2026.Repo.Migrations.CreateUserBadges do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:user_badges) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :badge_type, :string, null: false
      add :awarded_at, :naive_datetime, null: false

      timestamps()
    end

    create_if_not_exists unique_index(:user_badges, [:user_id, :badge_type])
    create_if_not_exists index(:user_badges, [:user_id])
  end
end

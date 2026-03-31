defmodule Jalka2026.Repo.Migrations.CreateUserFavoriteTeams do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:user_favorite_teams) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :is_primary, :boolean, default: false

      timestamps()
    end

    create_if_not_exists unique_index(:user_favorite_teams, [:user_id, :team_id])
    create_if_not_exists index(:user_favorite_teams, [:user_id])
    create_if_not_exists index(:user_favorite_teams, [:team_id])
  end
end

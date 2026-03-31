defmodule Jalka2026.Repo.Migrations.CreateUserStreaks do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:user_streaks) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :current_streak, :integer, default: 0, null: false
      add :longest_streak, :integer, default: 0, null: false
      add :bonus_points, :integer, default: 0, null: false

      timestamps()
    end

    create_if_not_exists unique_index(:user_streaks, [:user_id])
  end
end

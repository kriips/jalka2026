defmodule Jalka2026.Repo.Migrations.RemoveBonusPointsFromUserStreaks do
  use Ecto.Migration

  def up do
    alter table(:user_streaks) do
      remove :bonus_points
    end
  end

  def down do
    alter table(:user_streaks) do
      add :bonus_points, :integer, default: 0, null: false
    end
  end
end

defmodule Jalka2026.Repo.Migrations.AddThemeToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists :theme, :string, default: "light"
    end
  end
end

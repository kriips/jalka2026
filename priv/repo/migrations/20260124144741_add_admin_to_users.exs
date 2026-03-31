defmodule Jalka2026.Repo.Migrations.AddAdminToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists :is_admin, :boolean, default: false, null: false
    end
  end
end

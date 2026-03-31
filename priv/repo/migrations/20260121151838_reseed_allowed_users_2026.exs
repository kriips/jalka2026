defmodule Jalka2026.Repo.Migrations.ReseedAllowedUsers2026 do
  use Ecto.Migration
  require Logger
  import Ecto.Query

  def up do
    # Get prefix for file paths
    prefix = case Application.get_env(:jalka2026, :environment) do
      :prod -> "/app/lib/jalka2026-0.1.0"
      _ -> Mix.Project.app_path()
    end

    # Load the updated 2026 allowed users list
    users_file = "#{prefix}/priv/repo/data/allowed_users.json"
    users = Jason.decode!(File.read!(users_file))

    Logger.info("Reseeding allowed_users with #{length(users)} users for 2026 tournament...")

    # Insert new users that don't exist yet (by name)
    Enum.each(users, fn %{"id" => _id, "name" => name} ->
      # Check if user already exists (use count to handle potential duplicates)
      existing_count = Jalka2026.Repo.one(
        from a in "allowed_users",
        where: a.name == ^name,
        select: count(a.id)
      )

      if existing_count == 0 do
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        Jalka2026.Repo.insert_all("allowed_users", [
          %{name: name, inserted_at: now, updated_at: now}
        ])
      end
    end)

    final_count = Jalka2026.Repo.one(from a in "allowed_users", select: count(a.id))
    Logger.info("Allowed users table now has #{final_count} entries")
  end

  def down do
    # No rollback - data migration
    :ok
  end
end

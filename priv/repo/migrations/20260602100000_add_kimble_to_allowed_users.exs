defmodule Jalka2026.Repo.Migrations.AddKimbleToAllowedUsers do
  use Ecto.Migration

  # The allowed_users table is seeded once (when empty), so production —
  # already seeded with the full list — won't pick up new names from the
  # seed JSON. Add "kimble" for the current competition here instead.
  # Idempotent: the (name, competition_id) unique index makes the insert a
  # no-op if the row already exists.
  @name "kimble"
  @competition_id "wc-2026"

  def up do
    execute("""
    INSERT INTO allowed_users (name, competition_id, inserted_at, updated_at)
    VALUES ('#{@name}', '#{@competition_id}', NOW(), NOW())
    ON CONFLICT (name, competition_id) DO NOTHING
    """)
  end

  def down do
    execute(
      "DELETE FROM allowed_users WHERE name = '#{@name}' AND competition_id = '#{@competition_id}'"
    )
  end
end

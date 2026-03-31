defmodule Jalka2026.Repo.Migrations.CreateMatchComments do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:match_comments) do
      add :content, :text, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :match_id, references(:matches, on_delete: :delete_all), null: false

      timestamps()
    end

    create_if_not_exists index(:match_comments, [:match_id])
    create_if_not_exists index(:match_comments, [:user_id])
    create_if_not_exists index(:match_comments, [:match_id, :inserted_at])
  end
end

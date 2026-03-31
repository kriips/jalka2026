defmodule Jalka2026.Repo.Migrations.CreateBracketPredictions do
  use Ecto.Migration

  def up do
    # Drop tables if they exist with wrong schema (e.g., "phase" instead of "round")
    result =
      repo().query!(
        "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'bracket_predictions' AND column_name = 'round'",
        []
      )

    [[has_correct_schema]] = result.rows

    if has_correct_schema == 0 do
      execute("DROP TABLE IF EXISTS bracket_predictions")
    end

    result2 =
      repo().query!(
        "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'bracket_results' AND column_name = 'round'",
        []
      )

    [[has_correct_schema2]] = result2.rows

    if has_correct_schema2 == 0 do
      execute("DROP TABLE IF EXISTS bracket_results")
    end

    create_if_not_exists table(:bracket_predictions) do
      add :user_id, references("users", on_delete: :delete_all), null: false
      add :round, :string, null: false
      add :position, :integer, null: false
      add :team_id, references("teams", on_delete: :nilify_all)

      timestamps()
    end

    create_if_not_exists unique_index(:bracket_predictions, [:user_id, :round, :position])
    create_if_not_exists index(:bracket_predictions, [:user_id])
    create_if_not_exists index(:bracket_predictions, [:team_id])

    # Actual bracket results (admin-entered)
    create_if_not_exists table(:bracket_results) do
      add :round, :string, null: false
      add :position, :integer, null: false
      add :team_id, references("teams", on_delete: :nilify_all)

      timestamps()
    end

    create_if_not_exists unique_index(:bracket_results, [:round, :position])
  end

  def down do
    drop_if_exists table(:bracket_results)
    drop_if_exists table(:bracket_predictions)
  end
end

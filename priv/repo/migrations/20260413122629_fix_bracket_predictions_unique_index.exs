defmodule Jalka2026.Repo.Migrations.FixBracketPredictionsUniqueIndex do
  use Ecto.Migration

  def change do
    # Drop the old unconditional unique index that prevents overrides
    # from coexisting with winner predictions for the same position.
    drop_if_exists unique_index(:bracket_predictions, [:user_id, :round, :position])

    # Replace with a conditional index: only applies when side IS NULL (winner predictions)
    create_if_not_exists unique_index(:bracket_predictions, [:user_id, :round, :position],
      where: "side IS NULL",
      name: :bracket_predictions_user_round_pos_winner_index
    )
  end
end

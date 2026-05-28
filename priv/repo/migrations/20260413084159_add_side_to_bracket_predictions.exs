defmodule Jalka2026.Repo.Migrations.AddSideToBracketPredictions do
  use Ecto.Migration

  def change do
    alter table(:bracket_predictions) do
      add :side, :string
    end

    # Drop the old unconditional unique index so winner predictions and
    # matchup overrides can coexist for the same (user, round, position).
    drop_if_exists unique_index(:bracket_predictions, [:user_id, :round, :position])

    # Winner predictions: one per (user, round, position) when side IS NULL
    create unique_index(:bracket_predictions, [:user_id, :round, :position],
      where: "side IS NULL",
      name: :bracket_predictions_user_round_pos_winner_index
    )

    # Matchup overrides: one per (user, round, position, side) when side IS NOT NULL
    create unique_index(:bracket_predictions, [:user_id, :round, :position, :side],
      where: "side IS NOT NULL",
      name: :bracket_predictions_user_round_pos_side_index
    )
  end
end

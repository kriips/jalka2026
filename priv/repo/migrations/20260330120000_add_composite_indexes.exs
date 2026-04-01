defmodule Jalka2026.Repo.Migrations.AddCompositeIndexes do
  use Ecto.Migration

  @disable_ddl_transaction false

  def change do
    # playoff_predictions: no indexes exist at all
    # Covers: get_playoff_predictions_by_user(user_id), get_all_playoff_predictions_indexed()
    create_if_not_exists index(:playoff_predictions, [:user_id])

    # Covers: get_playoff_prediction_by_user_phase_team(user_id, phase, team_id)
    # and delete_playoff_predictions_by_user_team(user_id, team_id, phase)
    # Column order (user_id, phase, team_id) supports both equality lookups
    create_if_not_exists index(:playoff_predictions, [:user_id, :phase, :team_id])

    # matches: composite index for get_matches_by_group(group) which filters by competition_id + group
    # Replaces need to scan both separate indexes
    create_if_not_exists index(:matches, [:competition_id, :group])

    # matches: composite index for get_finished_matches() which filters by competition_id + finished
    create_if_not_exists index(:matches, [:competition_id, :finished])

    # group_prediction: standalone match_id index for get_predictions_by_match(match_id)
    create_if_not_exists index(:group_prediction, [:match_id])
  end
end

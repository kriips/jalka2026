defmodule Jalka2026.Repo.Migrations.CreateConflictRecords do
  use Ecto.Migration

  def change do
    create table(:conflict_records) do
      add :external_match_id, :string, null: false
      add :feed_score_home, :integer
      add :feed_score_away, :integer
      add :local_score_home, :integer
      add :local_score_away, :integer
      add :resolved_at, :utc_datetime
      add :resolution, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:conflict_records, [:external_match_id], where: "resolved_at IS NULL", name: :conflict_records_external_match_id_open_index)
  end
end

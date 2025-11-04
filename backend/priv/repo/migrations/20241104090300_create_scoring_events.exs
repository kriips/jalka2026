defmodule Jalka2026.Repo.Migrations.CreateScoringEvents do
  use Ecto.Migration

  def change do
    create table(:scoring_events) do
      add :match_id, :integer, null: false
      add :mode, :string, null: false
      add :affected_predictions_count, :integer
      add :latency_ms, :integer
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:scoring_events, [:match_id])
    create index(:scoring_events, [:mode, :inserted_at])
  end
end

defmodule Jalka2026.Repo.Migrations.CreateIngestionEvents do
  use Ecto.Migration

  def change do
    create table(:ingestion_events) do
      add :external_match_id, :string, null: false
      add :event_type, :string, null: false
      add :status, :string, null: false
      add :message, :text
      add :payload_hash, :string
      add :latency_ms, :integer
      timestamps(type: :utc_datetime)
    end

    create index(:ingestion_events, [:external_match_id, :status])
    create index(:ingestion_events, [:inserted_at])
    create unique_index(:ingestion_events, [:payload_hash], where: "status = 'success'", name: :ingestion_events_payload_hash_index)
  end
end

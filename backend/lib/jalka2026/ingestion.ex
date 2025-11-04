defmodule Jalka2026.Ingestion do
  @moduledoc """
  Ingestion context: logging ingestion events and conflict lifecycle.
  """
  import Ecto.Query
  alias Jalka2026.Repo
  alias Jalka2026.Ingestion.{IngestionEvent, ConflictRecord, Configuration}

  # Ingestion Events
  def log_event(attrs) do
    %IngestionEvent{} |> IngestionEvent.changeset(attrs) |> Repo.insert()
  end

  def recent_events(limit \ 50) do
    IngestionEvent
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  # Conflicts
  def open_conflicts do
    ConflictRecord
    |> where([c], is_nil(c.resolved_at))
    |> order_by(asc: :inserted_at)
    |> Repo.all()
  end

  def create_conflict(attrs) do
    %ConflictRecord{} |> ConflictRecord.changeset(attrs) |> Repo.insert()
  end

  def resolve_conflict(id, resolution) when resolution in ["approved", "rejected"] do
    case Repo.get(ConflictRecord, id) do
      nil -> {:error, :not_found}
      record ->
        record
        |> ConflictRecord.resolve_changeset(%{resolution: resolution})
        |> Repo.update()
    end
  end

  # Configuration (singleton id=1)
  def get_config do
    Repo.get(Configuration, 1)
  end

  def upsert_config(attrs) do
    case get_config() do
      nil -> %Configuration{id: 1} |> Configuration.changeset(attrs) |> Repo.insert()
      config -> config |> Configuration.changeset(attrs) |> Repo.update()
    end
  end
end

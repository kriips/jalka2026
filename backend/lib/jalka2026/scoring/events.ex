defmodule Jalka2026.Scoring.Events do
  @moduledoc """
  Context functions for ScoringEvent lifecycle.
  """
  import Ecto.Query
  alias Jalka2026.Repo
  alias Jalka2026.Scoring.ScoringEvent

  def record_event(attrs) do
    now = DateTime.utc_now()
    attrs = Map.put_new(attrs, :started_at, now)
    %ScoringEvent{} |> ScoringEvent.changeset(attrs) |> Repo.insert()
  end

  def complete_event(%ScoringEvent{} = event, affected_count, latency_ms) do
    event
    |> ScoringEvent.changeset(%{
      affected_predictions_count: affected_count,
      latency_ms: latency_ms,
      completed_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  def recent_events(limit \ 50) do
    ScoringEvent
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end
end

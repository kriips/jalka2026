defmodule Jalka2026.Test.Factory do
  alias Jalka2026.Repo
  alias Jalka2026.Ingestion.{IngestionEvent, ConflictRecord, Configuration}
  alias Jalka2026.Scoring.ScoringEvent

  def ingestion_event(attrs \\ %{}) do
    default = %{
      external_match_id: unique("match"),
      event_type: "ingested",
      status: "success"
    }

    %IngestionEvent{}
    |> IngestionEvent.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  def conflict_record(attrs \\ %{}) do
    default = %{
      external_match_id: unique("conflict_match"),
      feed_score_home: 1,
      feed_score_away: 0,
      local_score_home: 0,
      local_score_away: 0
    }

    %ConflictRecord{}
    |> ConflictRecord.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  def scoring_event(attrs \\ %{}) do
    default = %{
      match_id: 1,
      mode: "incremental"
    }

    %ScoringEvent{}
    |> ScoringEvent.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  def configuration(attrs \\ %{}) do
    base = %{
      id: 1,
      feed_enabled: false,
      polling_interval_seconds: 120,
      max_retries: 5,
      degraded_mode: false
    }

    %Configuration{id: 1}
    |> Configuration.changeset(Map.merge(base, attrs))
    |> Repo.insert!()
  end

  # Helpers
  defp unique(prefix) do
    :erlang.unique_integer([:positive]) |> Integer.to_string() |> then(&"#{prefix}_#{&1}")
  end
end

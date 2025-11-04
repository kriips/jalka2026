defmodule Jalka2026.Ingestion.MigrationsValidateTest do
  use ExUnit.Case, async: false
  alias Jalka2026.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "ingestion_events table exists with expected columns" do
    assert columns("ingestion_events") |> Enum.sort() |> Enum.member?("external_match_id")
    assert columns("ingestion_events") |> Enum.member?("event_type")
    assert columns("ingestion_events") |> Enum.member?("payload_hash")
  end

  test "conflict_records unique open index present" do
    idx = indexes("conflict_records") |> Enum.find(&String.contains?(&1, "open_index"))
    assert idx
  end

  test "scoring_events indexes" do
    mode_idx = indexes("scoring_events") |> Enum.find(&String.contains?(&1, "mode_inserted_at"))
    match_idx = indexes("scoring_events") |> Enum.find(&String.contains?(&1, "match_id"))
    assert mode_idx
    assert match_idx
  end

  test "feed_configuration singleton constraint present" do
    constraint = constraints("feed_configuration") |> Enum.find(&String.contains?(&1, "singleton_config"))
    assert constraint
  end

  defp columns(table) do
    Repo.query!("SELECT column_name FROM information_schema.columns WHERE table_name='#{table}'")
    |> Map.get(:rows)
    |> Enum.map(&hd/1)
  end

  defp indexes(table) do
    Repo.query!("SELECT indexname FROM pg_indexes WHERE tablename='#{table}'")
    |> Map.get(:rows)
    |> Enum.map(&hd/1)
  end

  defp constraints(table) do
    Repo.query!("SELECT conname FROM pg_constraint c JOIN pg_class t ON c.conrelid = t.oid WHERE t.relname='#{table}'")
    |> Map.get(:rows)
    |> Enum.map(&hd/1)
  end
end

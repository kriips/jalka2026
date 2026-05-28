defmodule Jalka2026.Seed.Helpers do
  @moduledoc """
  Shared utilities for seed repository implementations.
  """

  alias Ecto.Adapters.SQL
  alias Jalka2026.Repo

  @doc """
  Returns the application prefix path used to locate `priv/repo/data/` files.

  In production the release bundles assets under a versioned directory;
  in dev/test we derive the path from `Mix.Project.app_path/0`.
  """
  def prefix do
    case Application.get_env(:jalka2026, :environment) do
      :prod -> "/app/lib/jalka2026-0.1.0"
      _ -> Mix.Project.app_path()
    end
  end

  @doc """
  Returns the full filesystem path for a seed data file.
  """
  def data_path(filename, opts \\ []) do
    pfx = Keyword.get(opts, :prefix, prefix())
    "#{pfx}/priv/repo/data/#{filename}"
  end

  @doc """
  Returns the active competition ID (from opts or app config).
  """
  def competition_id(opts \\ []) do
    Keyword.get_lazy(opts, :competition_id, &Jalka2026.Competitions.current_id/0)
  end

  @doc """
  Returns a truncated `NaiveDateTime` suitable for DB timestamps.
  """
  def now do
    NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  end

  @doc """
  Check if a column exists on a table by querying the information_schema.
  """
  def column_exists?(table, column) do
    result =
      SQL.query!(
        Repo,
        "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = $1 AND column_name = $2",
        [table, column]
      )

    [[count]] = result.rows
    count > 0
  end

  @doc """
  Check if a table exists in the public schema.
  """
  def table_exists?(table) do
    result =
      SQL.query!(
        Repo,
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = $1 AND table_schema = 'public'",
        [table]
      )

    [[count]] = result.rows
    count > 0
  end

  @doc """
  Returns the row count for a table. Returns 0 if the table doesn't exist.
  """
  def row_count(table) do
    if table_exists?(table) do
      %{rows: [[count]]} =
        SQL.query!(Repo, "SELECT COUNT(*) FROM #{table}", [])

      count
    else
      0
    end
  end

  @doc """
  Execute a raw SQL query via the repo.
  """
  def query!(sql, params \\ []) do
    SQL.query!(Repo, sql, params)
  end

  @doc """
  Decode a JSON seed file. Returns the decoded data.
  """
  def read_json!(path) do
    Jason.decode!(File.read!(path))
  end
end

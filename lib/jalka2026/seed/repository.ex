defmodule Jalka2026.Seed.Repository do
  @moduledoc """
  Behaviour for seed data repositories.

  Each implementation handles one data type (teams, matches, etc.) and is
  independently callable and idempotent — calling `seed/1` when data already
  exists is a no-op.
  """

  @type opts :: keyword()

  @doc """
  Seed data into the database.

  Options:
    * `:prefix` – application path prefix (auto-detected when omitted)
    * `:competition_id` – override the current competition ID

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @callback seed(opts) :: :ok | {:error, term()}
end

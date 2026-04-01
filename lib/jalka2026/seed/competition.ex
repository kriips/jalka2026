defmodule Jalka2026.Seed.Competition do
  @moduledoc """
  Seeds the default competition record.

  Idempotent — skips if the competition already exists or the table is missing.
  """

  @behaviour Jalka2026.Seed.Repository

  alias Jalka2026.Seed.{Helpers, Parser, Runner}

  @impl true
  def seed(opts \\ []) do
    competition_id = Helpers.competition_id(opts)
    attrs = Parser.default_competition_attrs(competition_id)
    Runner.insert_competition(attrs, competition_id)
  end
end

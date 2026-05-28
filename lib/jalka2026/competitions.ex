defmodule Jalka2026.Competitions do
  @moduledoc """
  The Competitions context.

  Owns all competition-scoped queries and encapsulates `competition_id` filtering.
  Other contexts (Football, Accounts, Leaderboard) receive a `%Competition{}` struct
  or a competition_id string from this module rather than reading application config
  directly.
  """

  import Ecto.Query, warn: false

  alias Jalka2026.Football.Competition
  alias Jalka2026.Repo

  @type competition :: Competition.t()

  @doc """
  Returns the current competition ID from application config.

  This is the single source of truth for the active competition ID.
  All other modules should call this function instead of reading
  `Application.get_env(:jalka2026, :competition_id)` directly.
  """
  def current_id do
    Application.get_env(:jalka2026, :competition_id, "wc-2026")
  end

  @doc """
  Get the current active competition as a `%Competition{}` struct.

  Returns `nil` if the competition does not exist in the database.
  Uses the ETS cache when available (production), falls back to DB (test).
  """
  def current do
    Jalka2026.Football.Cache.get_current_competition()
  end

  @doc """
  Get the current competition, raising if it doesn't exist.
  """
  def current! do
    current() || raise "Competition #{current_id()} not found"
  end

  @doc """
  Get a competition by ID.

  Returns `nil` if the competition does not exist.
  """
  def get(id) when is_binary(id) do
    Repo.get(Competition, id)
  end

  @doc """
  Get a competition by ID, raising if it doesn't exist.
  """
  def get!(id) when is_binary(id) do
    Repo.get!(Competition, id)
  end

  @doc """
  List all competitions, ordered by year descending.
  """
  def list do
    from(c in Competition, order_by: [desc: c.year, asc: c.name])
    |> Repo.all()
  end

  @doc """
  List active competitions.
  """
  def list_active do
    from(c in Competition, where: c.is_active == true, order_by: [desc: c.year])
    |> Repo.all()
  end

  @doc """
  Create a new competition.
  """
  def create(attrs) do
    %Competition{}
    |> Competition.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update a competition.
  """
  def update(%Competition{} = competition, attrs) do
    competition
    |> Competition.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns the competition_id for use in queries.

  Accepts either a `%Competition{}` struct or a competition_id string.
  This is a convenience function for contexts that need to extract the ID
  for Ecto queries.

  ## Examples

      iex> Competitions.id(%Competition{id: "wc-2026"})
      "wc-2026"

      iex> Competitions.id("wc-2026")
      "wc-2026"

      iex> Competitions.id(nil)
      "wc-2026"  # falls back to current
  """
  def id(%Competition{id: id}), do: id
  def id(id) when is_binary(id), do: id
  def id(nil), do: current_id()
end

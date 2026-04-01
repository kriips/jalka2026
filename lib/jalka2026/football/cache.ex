defmodule Jalka2026.Football.Cache do
  @moduledoc """
  ETS-based cache for immutable tournament data (teams, group assignments, competition).
  Populated at application startup and serves lookups without hitting PostgreSQL.
  """

  use GenServer

  require Logger

  alias Jalka2026.Repo
  alias Jalka2026.Football.{Team, Competition}
  import Ecto.Query

  @teams_table :football_teams
  @competition_table :football_competitions

  ## Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns true if the cache is enabled (not in test environment).
  """
  def enabled? do
    Application.get_env(:jalka2026, :environment) != :test
  end

  @doc """
  Get all teams for the current competition. Returns a list of Team structs.
  Falls back to DB if cache is empty or disabled.
  """
  def get_teams do
    if enabled?() do
      case :ets.lookup(@teams_table, :all_teams) do
        [{:all_teams, teams}] -> teams
        [] -> fallback_get_teams()
      end
    else
      fallback_get_teams()
    end
  end

  @doc """
  Get a team by ID. Returns a Team struct or nil.
  Falls back to DB if not found in cache or cache disabled.
  """
  def get_team(id) do
    if enabled?() do
      case :ets.lookup(@teams_table, {:team_id, id}) do
        [{_, team}] -> team
        [] -> Repo.get(Team, id)
      end
    else
      Repo.get(Team, id)
    end
  end

  @doc """
  Get teams by name for the current competition. Returns a list of Team structs.
  Falls back to DB if cache miss or disabled.
  """
  def get_team_by_name(name) do
    if enabled?() do
      case :ets.lookup(@teams_table, {:team_name, name}) do
        [{_, teams}] -> teams
        [] -> fallback_get_team_by_name(name)
      end
    else
      fallback_get_team_by_name(name)
    end
  end

  @doc """
  Get teams grouped by group letter. Returns a map like %{"A" => [{id, name}, ...], ...}.
  Falls back to DB if cache is empty or disabled.
  """
  def get_teams_by_group do
    if enabled?() do
      case :ets.lookup(@teams_table, :teams_by_group) do
        [{:teams_by_group, grouped}] -> grouped
        [] -> fallback_get_teams_by_group()
      end
    else
      fallback_get_teams_by_group()
    end
  end

  @doc """
  Get the current competition. Returns a Competition struct or nil.
  """
  def get_current_competition do
    comp_id = Jalka2026.Competitions.current_id()

    if enabled?() do
      case :ets.lookup(@competition_table, comp_id) do
        [{_, competition}] -> competition
        [] -> Repo.get(Competition, comp_id)
      end
    else
      Repo.get(Competition, comp_id)
    end
  end

  @doc """
  Refresh the cache. Call this after admin operations that modify team data.
  """
  def refresh do
    GenServer.call(__MODULE__, :refresh)
  end

  ## GenServer callbacks

  @impl true
  def init(_opts) do
    :ets.new(@teams_table, [:set, :named_table, :protected, read_concurrency: true])
    :ets.new(@competition_table, [:set, :named_table, :protected, read_concurrency: true])

    {:ok, %{}, {:continue, :populate}}
  end

  @impl true
  def handle_continue(:populate, state) do
    if enabled?() do
      populate_cache()
    end

    {:noreply, state}
  end

  @impl true
  def handle_call(:refresh, _from, state) do
    populate_cache()
    {:reply, :ok, state}
  end

  ## Private helpers

  defp populate_cache do
    try do
      populate_teams()
      populate_competition()
      Logger.info("Football cache populated successfully")
    rescue
      e ->
        Logger.warning("Failed to populate football cache: #{inspect(e)}")
    end
  end

  defp populate_teams do
    comp_id = Jalka2026.Competitions.current_id()

    teams =
      from(t in Team, where: t.competition_id == ^comp_id)
      |> Repo.all()

    # Store all teams list
    :ets.insert(@teams_table, {:all_teams, teams})

    # Store individual teams by ID
    Enum.each(teams, fn team ->
      :ets.insert(@teams_table, {{:team_id, team.id}, team})
    end)

    # Store teams by name (list since get_team_by_name returns a list)
    teams
    |> Enum.group_by(& &1.name)
    |> Enum.each(fn {name, name_teams} ->
      :ets.insert(@teams_table, {{:team_name, name}, name_teams})
    end)

    # Store teams grouped by group letter with translated names
    alias Jalka2026.Football.TeamTranslations

    empty_groups = %{
      "A" => [], "B" => [], "C" => [], "D" => [],
      "E" => [], "F" => [], "G" => [], "H" => [],
      "I" => [], "J" => [], "K" => [], "L" => []
    }

    grouped =
      Enum.reduce(teams, empty_groups, fn team, acc ->
        translated_name = TeamTranslations.translate(team.name)
        Map.put(acc, team.group, [{team.id, translated_name} | acc[team.group]])
      end)

    :ets.insert(@teams_table, {:teams_by_group, grouped})
  end

  defp populate_competition do
    comp_id = Jalka2026.Competitions.current_id()

    case Repo.get(Competition, comp_id) do
      nil -> :ok
      competition -> :ets.insert(@competition_table, {comp_id, competition})
    end
  end

  # Fallbacks for when cache is not yet populated or missing data

  defp fallback_get_teams do
    comp_id = Jalka2026.Competitions.current_id()

    from(t in Team, where: t.competition_id == ^comp_id)
    |> Repo.all()
  end

  defp fallback_get_team_by_name(name) do
    comp_id = Jalka2026.Competitions.current_id()

    from(t in Team, where: t.name == ^name and t.competition_id == ^comp_id)
    |> Repo.all()
  end

  defp fallback_get_teams_by_group do
    alias Jalka2026.Football.TeamTranslations

    teams = fallback_get_teams()

    empty_groups = %{
      "A" => [], "B" => [], "C" => [], "D" => [],
      "E" => [], "F" => [], "G" => [], "H" => [],
      "I" => [], "J" => [], "K" => [], "L" => []
    }

    Enum.reduce(teams, empty_groups, fn team, acc ->
      translated_name = TeamTranslations.translate(team.name)
      Map.put(acc, team.group, [{team.id, translated_name} | acc[team.group]])
    end)
  end
end

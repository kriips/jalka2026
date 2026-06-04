defmodule Jalka2026.Football do
  @moduledoc """
  The Football context.

  Manages matches, predictions, teams, playoff data, historical matchups,
  and bracket predictions for the current competition. Functions return
  Ecto schema structs (`%Match{}`, `%GroupPrediction{}`, `%Team{}`, etc.).
  """

  require Logger

  import Ecto.Query, warn: false
  alias Jalka2026.Repo

  alias Jalka2026.Competitions

  alias Jalka2026.Football.{
    BracketPrediction,
    BracketResult,
    Cache,
    Competition,
    GroupPrediction,
    HistoricalMatch,
    Match,
    PlayoffPrediction,
    PlayoffResult,
    TournamentStanding,
    UserFavoriteTeam,
    UserRivalry
  }

  alias Jalka2026.Telemetry.Events, as: TelemetryEvents
  alias Jalka2026Web.Resolvers.FootballResolver

  @type match :: Match.t()
  @type prediction :: GroupPrediction.t()
  @type team :: Jalka2026.Football.Team.t()

  ## Canonical Group List

  @groups ~w(A B C D E F G H I J K L)

  @doc ~S'Returns the canonical list of group letters, e.g. ["A", "B", ..., "L"].'
  def groups, do: @groups

  @doc "Returns group names as stored on matches, e.g. [\"Alagrupp A\", ...]."
  def match_groups, do: Enum.map(@groups, &"Alagrupp #{&1}")

  @doc "Builds a map from group letters to the given default value."
  def empty_group_map(default \\ []) do
    Map.new(@groups, &{&1, default})
  end

  @doc "Builds a map from match group names to the given default value."
  def empty_match_group_map(default \\ 0) do
    Map.new(@groups, &{"Alagrupp #{&1}", default})
  end

  ## Competition Management
  ## Delegated to Jalka2026.Competitions context — these remain for backward compatibility.

  @doc """
  Returns the current competition ID from application config.
  Delegates to `Jalka2026.Competitions.current_id/0`.
  """
  def competition_id, do: Competitions.current_id()

  @doc """
  Get a competition by ID.
  Delegates to `Jalka2026.Competitions.get/1`.
  """
  def get_competition(id), do: Competitions.get(id)

  @doc """
  Get the current active competition.
  Delegates to `Jalka2026.Competitions.current/0`.
  """
  def get_current_competition, do: Competitions.current()

  @doc """
  List all competitions, ordered by year descending.
  Delegates to `Jalka2026.Competitions.list/0`.
  """
  def list_competitions, do: Competitions.list()

  @doc """
  List active competitions.
  Delegates to `Jalka2026.Competitions.list_active/0`.
  """
  def list_active_competitions, do: Competitions.list_active()

  @doc """
  Create a new competition.
  Delegates to `Jalka2026.Competitions.create/1`.
  """
  def create_competition(attrs), do: Competitions.create(attrs)

  @doc """
  Update a competition.
  Delegates to `Jalka2026.Competitions.update/2`.
  """
  def update_competition(%Competition{} = competition, attrs),
    do: Competitions.update(competition, attrs)

  alias Jalka2026.Football.CodesMap

  @doc """
  Convert FIFA team code to ISO 3166-1 alpha-3 code for historical data lookup.
  Returns the original code if no mapping exists.

  Delegates to `Jalka2026.Football.CodesMap.fifa_to_iso/1`.
  """
  defdelegate fifa_to_iso_code(fifa_code), to: CodesMap, as: :fifa_to_iso

  ## Database getters

  def get_matches_by_group(group) when is_binary(group) do
    TelemetryEvents.span_match_listing(%{source: :matches_by_group, group: group}, fn ->
      comp_id = competition_id()

      query =
        from(m in Match,
          where: m.group == ^group and m.competition_id == ^comp_id,
          order_by: m.date,
          preload: [:home_team, :away_team]
        )

      Repo.all(query)
    end)
  end

  def get_finished_matches() do
    TelemetryEvents.span_match_listing(%{source: :finished_matches}, fn ->
      comp_id = competition_id()

      query =
        from(m in Match,
          where: m.finished == true and m.competition_id == ^comp_id,
          order_by: m.date
        )

      Repo.all(query)
    end)
  end

  def get_playoff_results() do
    comp_id = competition_id()
    query = from(pr in PlayoffResult, where: pr.competition_id == ^comp_id)

    Repo.all(query)
  end

  def get_matches() do
    TelemetryEvents.span_match_listing(%{source: :all_matches}, fn ->
      comp_id = competition_id()

      query =
        from(m in Match,
          where: m.competition_id == ^comp_id,
          order_by: m.date,
          preload: [:home_team, :away_team]
        )

      Repo.all(query)
      |> Enum.map(fn match ->
        %Match{match | date: Timex.shift(match.date, hours: +2)}
      end)
    end)
  end

  def get_match(id) do
    Repo.get_by(Match, id: id) |> Repo.preload([:home_team, :away_team])
  end

  def get_prediction_by_user_match(user_id, match_id) do
    Repo.get_by(GroupPrediction, user_id: user_id, match_id: match_id)
  end

  @doc """
  Load all group predictions as a map indexed by {user_id, match_id}.
  Used by leaderboard to avoid N+1 queries.
  """
  def get_all_predictions_indexed() do
    TelemetryEvents.span_prediction_load(%{source: :all_predictions_indexed}, fn ->
      Repo.all(GroupPrediction)
      |> Map.new(fn p -> {{p.user_id, p.match_id}, p} end)
    end)
  end

  @doc """
  Load all group predictions grouped by user_id, where each user's predictions
  are a map of match_id => prediction.
  Used by streak/badge calculation to avoid N+1 queries.
  """
  def get_all_predictions_by_user() do
    TelemetryEvents.span_prediction_load(%{source: :all_predictions_by_user}, fn ->
      Repo.all(GroupPrediction)
      |> Enum.group_by(& &1.user_id)
      |> Map.new(fn {user_id, predictions} ->
        {user_id, Map.new(predictions, fn p -> {p.match_id, p} end)}
      end)
    end)
  end

  @doc """
  Load all playoff predictions grouped by user_id.
  Returns %{user_id => %{phase => [team_id, ...]}}
  Used by leaderboard to avoid N+1 queries.
  """
  def get_all_playoff_predictions_indexed() do
    TelemetryEvents.span_prediction_load(%{source: :all_playoff_predictions_indexed}, fn ->
      # Derived from bracket winner picks (side: nil) — the source of truth — NOT the drift-prone
      # playoff_predictions table. Single query (no preload).
      from(bp in BracketPrediction,
        where: is_nil(bp.side),
        select: {bp.user_id, bp.round, bp.team_id}
      )
      |> Repo.all()
      |> Enum.group_by(fn {user_id, _round, _team_id} -> user_id end)
      |> Map.new(fn {user_id, rows} -> {user_id, index_bracket_picks(rows)} end)
    end)
  end

  defp index_bracket_picks(rows) do
    Enum.reduce(rows, %{32 => [], 16 => [], 8 => [], 4 => [], 2 => []}, fn {_uid, round, team_id},
                                                                          acc ->
      case BracketPrediction.round_to_phase(round) do
        nil -> acc
        phase -> Map.update(acc, phase, [team_id], &[team_id | &1])
      end
    end)
  end

  @doc """
  Playoff predictions derived from bracket winner picks (side: nil) for ALL users, as a list of
  maps `%{phase, team_id, team, user_id, user}`. Source of truth for the playoff overview/scoring
  display (avoids stale orphans in the playoff_predictions table).
  """
  def bracket_playoff_predictions_with_user() do
    from(bp in BracketPrediction, where: is_nil(bp.side), preload: [:team, :user])
    |> Repo.all()
    |> Enum.map(fn bp ->
      %{
        phase: BracketPrediction.round_to_phase(bp.round),
        team_id: bp.team_id,
        team: bp.team,
        user_id: bp.user_id,
        user: bp.user
      }
    end)
  end

  @doc """
  Playoff predictions derived from a user's bracket winner picks, as a list of maps
  `%{phase, team_id, team}`.
  """
  def bracket_playoff_predictions_by_user(user_id) do
    from(bp in BracketPrediction, where: bp.user_id == ^user_id and is_nil(bp.side), preload: [:team])
    |> Repo.all()
    |> Enum.map(fn bp ->
      %{phase: BracketPrediction.round_to_phase(bp.round), team_id: bp.team_id, team: bp.team}
    end)
  end

  @doc """
  All group-stage matches for the current competition, grouped by their group string
  (e.g. `%{"Alagrupp A" => [match, ...]}`), with teams preloaded. Single query — used for bulk
  predicted-standings computation (avoids per-user, per-group N+1).
  """
  def get_group_matches_grouped() do
    comp_id = competition_id()

    from(m in Match,
      where: like(m.group, "Alagrupp %") and m.competition_id == ^comp_id,
      order_by: m.date,
      preload: [:home_team, :away_team]
    )
    |> Repo.all()
    |> Enum.group_by(& &1.group)
  end

  @doc """
  All bracket matchup overrides (rows with a non-nil `side`) for ALL users, grouped as
  `%{user_id => %{round => [bracket_prediction, ...]}}`, with team preloaded. Single query —
  used for bulk last-32 computation.
  """
  def all_bracket_overrides_by_round() do
    from(bp in BracketPrediction, where: not is_nil(bp.side), preload: [:team])
    |> Repo.all()
    |> Enum.group_by(& &1.user_id)
    |> Map.new(fn {user_id, rows} -> {user_id, Enum.group_by(rows, & &1.round)} end)
  end

  def get_predictions_by_match(match_id) do
    query =
      from(gp in GroupPrediction,
        where: gp.match_id == ^match_id,
        preload: [:user]
      )

    Repo.all(query)
  end

  def get_team_by_name(team_name) do
    Cache.get_team_by_name(team_name)
  end

  @doc """
  Get a team by ID.
  """
  def get_team(id) do
    Cache.get_team(id)
  end

  def get_predictions_by_user(user_id) do
    query =
      from(gp in GroupPrediction,
        where: gp.user_id == ^user_id,
        preload: [match: [:home_team, :away_team]]
      )

    Repo.all(query)
  end

  def get_playoff_predictions() do
    query =
      from(pp in PlayoffPrediction,
        preload: [:user, :team]
      )

    Repo.all(query)
  end

  def get_playoff_predictions_by_user(user_id) do
    query =
      from(pp in PlayoffPrediction,
        where: pp.user_id == ^user_id,
        preload: [:team]
      )

    Repo.all(query)
  end

  def get_playoff_prediction_by_user_phase_team(user_id, phase, team_id) do
    Repo.get_by(PlayoffPrediction, user_id: user_id, team_id: team_id, phase: phase)
  end

  def get_playoff_result_by_phase_team(phase, team_id) do
    Repo.get_by(PlayoffResult, team_id: team_id, phase: phase)
  end

  def delete_playoff_predictions_by_user_team(user_id, team_id, phase) do
    query =
      from(pp in PlayoffPrediction,
        where: pp.user_id == ^user_id and pp.team_id == ^team_id and pp.phase <= ^phase
      )

    Repo.delete_all(query)
  end

  def change_score(
        %{
          user_id: user_id,
          match_id: match_id,
          home_score: _home_score,
          away_score: _away_score
        } = attrs
      ) do
    metadata = %{user_id: user_id, match_id: match_id}

    result =
      TelemetryEvents.span_group_prediction(metadata, fn ->
        case get_prediction_by_user_match(user_id, match_id) do
          %GroupPrediction{} = prediction ->
            prediction |> GroupPrediction.create_changeset(attrs) |> Repo.update!()

          nil ->
            %GroupPrediction{} |> GroupPrediction.create_changeset(attrs) |> Repo.insert!()
        end
      end)

    # Notify rivals about differing predictions (async to not block the request)
    parent = self()

    Task.start(fn ->
      try do
        Ecto.Adapters.SQL.Sandbox.allow(Jalka2026.Repo, parent, self())
        Jalka2026.RivalryNotifications.check_and_notify_rivals(user_id, match_id, attrs)
      rescue
        _ -> :ok
      catch
        :exit, _ -> :ok
      end
    end)

    result
  end

  def update_match_score(game_id, home_score, away_score) do
    case get_match(game_id) do
      %Match{} = match ->
        match
        |> Match.create_changeset(%{
          home_score: home_score,
          away_score: away_score,
          finished: true,
          result: Jalka2026.Scoring.calculate_result(home_score, away_score)
        })
        |> Repo.update!()

      nil ->
        Logger.warning("Incorrect game id: #{game_id}")
    end
  end

  @doc """
  Enters a group match result using an Ecto.Multi pipeline.

  The database mutations are wrapped in a transaction for atomicity.
  Side effects (leaderboard recalculation, notifications) run after
  the transaction commits successfully.

  Named steps:
    - `:validate_match` – loads and validates the match exists
    - `:update_match` – persists the score, result and finished flag
    - `:recalc_leaderboard` – triggers leaderboard recalculation (post-commit)
    - `:send_notifications` – fires async email notifications (post-commit)

  Returns `{:ok, %{update_match: match, recalc_leaderboard: leaderboard, ...}}`
  or `{:error, failed_step, reason, changes_so_far}`.
  """
  def enter_match_result(game_id, home_score, away_score) do
    multi_result =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:validate_match, fn _repo, _changes ->
        case get_match(game_id) do
          %Match{} = match -> {:ok, match}
          nil -> {:error, :match_not_found}
        end
      end)
      |> Ecto.Multi.run(:update_match, fn _repo, %{validate_match: match} ->
        match
        |> Match.create_changeset(%{
          home_score: home_score,
          away_score: away_score,
          finished: true,
          result: Jalka2026.Scoring.calculate_result(home_score, away_score)
        })
        |> Repo.update()
      end)
      |> Repo.transaction()

    case multi_result do
      {:ok, changes} ->
        # Side effects run only after a successful commit
        leaderboard = Jalka2026.Leaderboard.recalc_leaderboard()
        leaderboard_changes = extract_leaderboard_changes(leaderboard)
        Jalka2026.MatchResultNotifications.send_notifications(game_id, leaderboard_changes)

        {:ok, Map.merge(changes, %{recalc_leaderboard: leaderboard, send_notifications: :sent})}

      error ->
        error
    end
  end

  @doc """
  Enters a playoff result using an Ecto.Multi pipeline.

  The database mutations are wrapped in a transaction for atomicity.
  Side effects (leaderboard recalculation, notifications) run after
  the transaction commits successfully.

  Named steps:
    - `:resolve_team` – resolves team name to team record
    - `:toggle_playoff_result` – inserts or deletes the playoff result (toggle)
    - `:recalc_leaderboard` – triggers leaderboard recalculation (post-commit)
    - `:send_notifications` – fires async email notifications (post-commit)

  Returns `{:ok, %{toggle_playoff_result: result, ...}}`
  or `{:error, failed_step, reason, changes_so_far}`.
  """
  def enter_playoff_result(team_name, phase) do
    phase_int = if is_binary(phase), do: String.to_integer(phase), else: phase

    multi_result =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:resolve_team, fn _repo, _changes ->
        case get_team_by_name(team_name) do
          [team | _] -> {:ok, team}
          [] -> {:error, :team_not_found}
        end
      end)
      |> Ecto.Multi.run(:toggle_playoff_result, fn _repo, %{resolve_team: team} ->
        case get_playoff_result_by_phase_team(phase_int, team.id) do
          %PlayoffResult{} = result ->
            Repo.delete(result)

          nil ->
            %PlayoffResult{}
            |> PlayoffResult.create_changeset(%{
              phase: phase_int,
              team_id: team.id,
              competition_id: competition_id()
            })
            |> Repo.insert()
        end
      end)
      |> Repo.transaction()

    case multi_result do
      {:ok, %{resolve_team: team} = changes} ->
        # Side effects run only after a successful commit
        leaderboard = Jalka2026.Leaderboard.recalc_leaderboard()
        Jalka2026.MatchResultNotifications.send_playoff_notifications(phase_int, team.id, %{})

        {:ok, Map.merge(changes, %{recalc_leaderboard: leaderboard, send_notifications: :sent})}

      error ->
        error
    end
  end

  defp extract_leaderboard_changes(_leaderboard) do
    # Build a map of user_id => %{rank_change: nil, points_change: nil}
    # Since we don't have the old leaderboard here, we pass empty changes
    # The notifications module will handle missing change data gracefully
    %{}
  end

  def update_playoff_result(phase, team_id) do
    case get_playoff_result_by_phase_team(phase, team_id) do
      %PlayoffResult{} = result ->
        result |> Repo.delete!()

      nil ->
        %PlayoffResult{}
        |> PlayoffResult.create_changeset(%{
          phase: phase,
          team_id: team_id,
          competition_id: competition_id()
        })
        |> Repo.insert!()
    end
  end

  def get_teams() do
    Cache.get_teams()
  end

  def add_playoff_prediction(%{user_id: user_id, team_id: team_id, phase: phase} = attrs) do
    metadata = %{user_id: user_id, team_id: team_id, phase: phase, action: :add}

    TelemetryEvents.span_playoff_prediction(metadata, fn ->
      case get_playoff_prediction_by_user_phase_team(user_id, phase, team_id) do
        %PlayoffPrediction{} = prediction ->
          prediction |> PlayoffPrediction.create_changeset(attrs) |> Repo.update!()

        nil ->
          %PlayoffPrediction{} |> PlayoffPrediction.create_changeset(attrs) |> Repo.insert!()
      end
    end)
  end

  def remove_playoff_prediction(%{user_id: user_id, team_id: team_id, phase: phase}) do
    metadata = %{user_id: user_id, team_id: team_id, phase: phase, action: :remove}

    TelemetryEvents.span_playoff_prediction(metadata, fn ->
      delete_playoff_predictions_by_user_team(user_id, team_id, phase)
    end)
  end

  ## Historical Matchup Data

  @doc """
  Get all historical matches between two teams (by team code).
  Returns matches where either team was home or away.
  """
  def get_historical_matchup(team1_code, team2_code) do
    iso1 = fifa_to_iso_code(team1_code)
    iso2 = fifa_to_iso_code(team2_code)

    query =
      from(hm in HistoricalMatch,
        where:
          (hm.home_team_code == ^iso1 and hm.away_team_code == ^iso2) or
            (hm.home_team_code == ^iso2 and hm.away_team_code == ^iso1),
        order_by: [desc: hm.date]
      )

    Repo.all(query)
  end

  @doc """
  Get all World Cup matches between two teams.
  """
  def get_world_cup_matchup(team1_code, team2_code) do
    iso1 = fifa_to_iso_code(team1_code)
    iso2 = fifa_to_iso_code(team2_code)

    query =
      from(hm in HistoricalMatch,
        where:
          hm.is_world_cup == true and
            ((hm.home_team_code == ^iso1 and hm.away_team_code == ^iso2) or
               (hm.home_team_code == ^iso2 and hm.away_team_code == ^iso1)),
        order_by: [desc: hm.date]
      )

    Repo.all(query)
  end

  @doc """
  Get historical statistics between two teams.
  Returns a map with wins, draws, losses, goals for/against for team1.
  """
  def get_historical_stats(team1_code, team2_code) do
    iso1 = fifa_to_iso_code(team1_code)
    matches = get_historical_matchup(team1_code, team2_code)

    initial = %{
      total_matches: 0,
      team1_wins: 0,
      team2_wins: 0,
      draws: 0,
      team1_goals: 0,
      team2_goals: 0
    }

    Enum.reduce(matches, initial, fn match, acc ->
      {team1_goals, team2_goals} =
        if match.home_team_code == iso1 do
          {match.home_score, match.away_score}
        else
          {match.away_score, match.home_score}
        end

      win_status =
        cond do
          team1_goals > team2_goals -> :team1_win
          team2_goals > team1_goals -> :team2_win
          true -> :draw
        end

      %{
        acc
        | total_matches: acc.total_matches + 1,
          team1_wins: acc.team1_wins + if(win_status == :team1_win, do: 1, else: 0),
          team2_wins: acc.team2_wins + if(win_status == :team2_win, do: 1, else: 0),
          draws: acc.draws + if(win_status == :draw, do: 1, else: 0),
          team1_goals: acc.team1_goals + team1_goals,
          team2_goals: acc.team2_goals + team2_goals
      }
    end)
  end

  @doc """
  Get recent form - last N matches for a team.
  """
  def get_team_recent_form(team_code, limit \\ 5) do
    iso_code = fifa_to_iso_code(team_code)

    query =
      from(hm in HistoricalMatch,
        where: hm.home_team_code == ^iso_code or hm.away_team_code == ^iso_code,
        order_by: [desc: hm.date],
        limit: ^limit
      )

    matches = Repo.all(query)

    Enum.map(matches, fn match ->
      {goals_for, goals_against, opponent_code, opponent_name, is_home} =
        if match.home_team_code == iso_code do
          {match.home_score, match.away_score, match.away_team_code, match.away_team_name, true}
        else
          {match.away_score, match.home_score, match.home_team_code, match.home_team_name, false}
        end

      result =
        cond do
          goals_for > goals_against -> "W"
          goals_against > goals_for -> "L"
          true -> "D"
        end

      %{
        date: match.date,
        opponent_code: opponent_code,
        opponent_name: opponent_name,
        goals_for: goals_for,
        goals_against: goals_against,
        result: result,
        is_home: is_home,
        competition: match.competition
      }
    end)
  end

  @doc """
  Get all World Cup matches for a team (historical World Cup record).
  """
  def get_team_world_cup_history(team_code) do
    iso_code = fifa_to_iso_code(team_code)

    query =
      from(hm in HistoricalMatch,
        where:
          hm.is_world_cup == true and
            (hm.home_team_code == ^iso_code or hm.away_team_code == ^iso_code),
        order_by: [desc: hm.date]
      )

    Repo.all(query)
  end

  @doc """
  Get World Cup statistics for a team.
  """
  def get_team_world_cup_stats(team_code) do
    iso_code = fifa_to_iso_code(team_code)
    matches = get_team_world_cup_history(team_code)

    initial = %{
      matches_played: 0,
      wins: 0,
      draws: 0,
      losses: 0,
      goals_for: 0,
      goals_against: 0
    }

    Enum.reduce(matches, initial, fn match, acc ->
      {goals_for, goals_against} =
        if match.home_team_code == iso_code do
          {match.home_score, match.away_score}
        else
          {match.away_score, match.home_score}
        end

      result =
        cond do
          goals_for > goals_against -> :win
          goals_against > goals_for -> :loss
          true -> :draw
        end

      %{
        acc
        | matches_played: acc.matches_played + 1,
          wins: acc.wins + if(result == :win, do: 1, else: 0),
          draws: acc.draws + if(result == :draw, do: 1, else: 0),
          losses: acc.losses + if(result == :loss, do: 1, else: 0),
          goals_for: acc.goals_for + goals_for,
          goals_against: acc.goals_against + goals_against
      }
    end)
  end

  @doc """
  Get World Cup statistics for a team broken down by tournament year.
  Returns a list of tournament stats sorted by year (most recent first).
  """
  def get_team_world_cup_stats_by_tournament(team_code) do
    iso_code = fifa_to_iso_code(team_code)
    matches = get_team_world_cup_history(team_code)

    # Group matches by World Cup year (using the year from the match date)
    matches
    |> Enum.group_by(fn match -> match.date.year end)
    |> Enum.map(fn {year, tournament_matches} ->
      stats = calculate_tournament_stats(iso_code, tournament_matches)
      Map.put(stats, :year, year)
    end)
    |> Enum.sort_by(& &1.year, :desc)
  end

  defp calculate_tournament_stats(iso_code, matches) do
    initial = %{
      matches_played: 0,
      wins: 0,
      draws: 0,
      losses: 0,
      goals_for: 0,
      goals_against: 0
    }

    Enum.reduce(matches, initial, fn match, acc ->
      {goals_for, goals_against} =
        if match.home_team_code == iso_code do
          {match.home_score, match.away_score}
        else
          {match.away_score, match.home_score}
        end

      result =
        cond do
          goals_for > goals_against -> :win
          goals_against > goals_for -> :loss
          true -> :draw
        end

      %{
        acc
        | matches_played: acc.matches_played + 1,
          wins: acc.wins + if(result == :win, do: 1, else: 0),
          draws: acc.draws + if(result == :draw, do: 1, else: 0),
          losses: acc.losses + if(result == :loss, do: 1, else: 0),
          goals_for: acc.goals_for + goals_for,
          goals_against: acc.goals_against + goals_against
      }
    end)
  end

  @doc """
  Get World Cup tournament positions (1st-4th place finishes) for a team.
  Returns a map with position counts and a list of finishes by year.
  """
  def get_team_world_cup_positions(team_code) do
    iso_code = fifa_to_iso_code(team_code)

    query =
      from(ts in TournamentStanding,
        where: ts.team_code == ^iso_code,
        order_by: [desc: ts.tournament_id]
      )

    standings = Repo.all(query)

    position_counts = %{
      gold: Enum.count(standings, &(&1.position == 1)),
      silver: Enum.count(standings, &(&1.position == 2)),
      bronze: Enum.count(standings, &(&1.position == 3)),
      fourth: Enum.count(standings, &(&1.position == 4))
    }

    finishes =
      Enum.map(standings, fn standing ->
        # Extract year from tournament_id (e.g., "WC-1930" -> 1930)
        year =
          standing.tournament_id
          |> String.replace("WC-", "")
          |> String.to_integer()

        %{
          year: year,
          position: standing.position,
          tournament_name: standing.tournament_name
        }
      end)

    %{
      counts: position_counts,
      finishes: finishes,
      total_top_4: length(standings)
    }
  end

  @doc """
  Get the elimination stage for a team in a World Cup where they didn't finish top 4.
  Analyzes historical matches to determine the furthest stage reached.
  Returns a map of year => elimination_stage.
  """
  def get_team_world_cup_eliminations(team_code) do
    iso_code = fifa_to_iso_code(team_code)

    # Get all WC matches for this team
    matches = get_team_world_cup_history(team_code)

    # Get top 4 finishes to exclude those years
    top4_query =
      from(ts in TournamentStanding,
        where: ts.team_code == ^iso_code,
        select: ts.tournament_id
      )

    top4_tournament_ids = Repo.all(top4_query)

    top4_years =
      Enum.map(top4_tournament_ids, fn id ->
        id |> String.replace("WC-", "") |> String.to_integer()
      end)

    # Group matches by year and find furthest stage for each
    matches
    |> Enum.group_by(fn match -> match.date.year end)
    |> Enum.reject(fn {year, _} -> year in top4_years end)
    |> Enum.map(fn {year, tournament_matches} ->
      furthest_stage = get_furthest_stage(tournament_matches)
      {year, furthest_stage}
    end)
    |> Map.new()
  end

  # Stage priority - higher number = further in tournament
  @stage_priority %{
    "group stage" => 1,
    "second group stage" => 2,
    "round of 16" => 3,
    "quarter-finals" => 4,
    "semi-finals" => 5,
    "third-place match" => 6,
    "final" => 7,
    "final round" => 7
  }

  defp get_furthest_stage(matches) do
    matches
    |> Enum.map(fn match ->
      stage = match.stage |> String.downcase()
      priority = Map.get(@stage_priority, stage, 0)
      {stage, priority}
    end)
    |> Enum.max_by(fn {_stage, priority} -> priority end, fn -> {"group stage", 1} end)
    |> elem(0)
  end

  @doc """
  Get stage display name in Estonian.
  """
  def stage_display_name(stage) do
    case String.downcase(stage) do
      "group stage" -> "Alagrupifaas"
      "second group stage" -> "Teine alagrupifaas"
      "round of 16" -> "16. finaal"
      "quarter-finals" -> "Veerandfinaal"
      "semi-finals" -> "Poolfinaal"
      "third-place match" -> "3. koha mäng"
      "final" -> "Finaal"
      "final round" -> "Finaalring"
      _ -> stage
    end
  end

  @doc """
  Get short stage display name for compact display.
  """
  def stage_short_name(stage) do
    case String.downcase(stage) do
      "group stage" -> "Grupp"
      "second group stage" -> "2. grupp"
      "round of 16" -> "R16"
      "quarter-finals" -> "VF"
      "semi-finals" -> "PF"
      "third-place match" -> "3./4."
      "final" -> "1./2."
      "final round" -> "1./2."
      _ -> stage
    end
  end

  ## User Favorite Teams

  @doc """
  Get all favorite teams for a user.
  """
  def get_user_favorite_teams(user_id) do
    query =
      from(uft in UserFavoriteTeam,
        where: uft.user_id == ^user_id,
        preload: [:team],
        order_by: [desc: uft.is_primary, asc: uft.inserted_at]
      )

    Repo.all(query)
  end

  @doc """
  Get the primary favorite team for a user.
  """
  def get_user_primary_team(user_id) do
    query =
      from(uft in UserFavoriteTeam,
        where: uft.user_id == ^user_id and uft.is_primary == true,
        preload: [:team],
        limit: 1
      )

    Repo.one(query)
  end

  @doc """
  Get favorite teams for multiple users (for leaderboard display).
  Returns a map of user_id => list of favorite teams.
  """
  def get_favorite_teams_for_users(user_ids) when is_list(user_ids) do
    query =
      from(uft in UserFavoriteTeam,
        where: uft.user_id in ^user_ids,
        preload: [:team],
        order_by: [desc: uft.is_primary, asc: uft.inserted_at]
      )

    Repo.all(query)
    |> Enum.group_by(& &1.user_id)
  end

  @doc """
  Add a favorite team for a user.
  """
  def add_favorite_team(user_id, team_id, is_primary \\ false) do
    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:unset_primary, fn _repo, _changes ->
        if is_primary do
          unset_primary_team(user_id)
        end

        {:ok, :done}
      end)
      |> Ecto.Multi.run(:insert_favorite, fn _repo, _changes ->
        %UserFavoriteTeam{}
        |> UserFavoriteTeam.changeset(%{
          user_id: user_id,
          team_id: team_id,
          is_primary: is_primary
        })
        |> Repo.insert()
      end)

    case Repo.transaction(multi) do
      {:ok, %{insert_favorite: favorite}} -> {:ok, favorite}
      {:error, _step, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Remove a favorite team for a user.
  """
  def remove_favorite_team(user_id, team_id) do
    query =
      from(uft in UserFavoriteTeam,
        where: uft.user_id == ^user_id and uft.team_id == ^team_id
      )

    Repo.delete_all(query)
  end

  @doc """
  Set a team as the primary favorite for a user.
  """
  def set_primary_team(user_id, team_id) do
    Repo.transaction(fn ->
      # First unset any existing primary
      unset_primary_team(user_id)

      # Then set the new primary
      query =
        from(uft in UserFavoriteTeam,
          where: uft.user_id == ^user_id and uft.team_id == ^team_id
        )

      case Repo.one(query) do
        nil ->
          # Team is not in favorites, add it as primary
          %UserFavoriteTeam{}
          |> UserFavoriteTeam.changeset(%{user_id: user_id, team_id: team_id, is_primary: true})
          |> Repo.insert!()

        favorite ->
          favorite
          |> Ecto.Changeset.change(is_primary: true)
          |> Repo.update!()
      end
    end)
  end

  defp unset_primary_team(user_id) do
    query =
      from(uft in UserFavoriteTeam,
        where: uft.user_id == ^user_id and uft.is_primary == true
      )

    Repo.update_all(query, set: [is_primary: false])
  end

  @doc """
  Check if a team is a user's favorite.
  """
  def favorite_team?(user_id, team_id) do
    query =
      from(uft in UserFavoriteTeam,
        where: uft.user_id == ^user_id and uft.team_id == ^team_id
      )

    Repo.exists?(query)
  end

  @doc """
  Get prediction bias statistics for a user.
  Compares accuracy when predicting for favorite teams vs other teams.
  """
  def get_prediction_bias_stats(user_id) do
    favorite_teams = get_user_favorite_teams(user_id)
    favorite_team_ids = Enum.map(favorite_teams, & &1.team_id)

    if favorite_team_ids == [] do
      %{
        has_favorites: false,
        favorite_predictions: 0,
        favorite_correct_results: 0,
        favorite_correct_scores: 0,
        other_predictions: 0,
        other_correct_results: 0,
        other_correct_scores: 0
      }
    else
      predictions = get_predictions_by_user(user_id)
      finished_matches = get_finished_matches() |> Enum.map(& &1.id) |> MapSet.new()

      stats =
        predictions
        |> Enum.filter(fn pred -> MapSet.member?(finished_matches, pred.match_id) end)
        |> Enum.reduce(
          %{
            favorite_predictions: 0,
            favorite_correct_results: 0,
            favorite_correct_scores: 0,
            other_predictions: 0,
            other_correct_results: 0,
            other_correct_scores: 0
          },
          &accumulate_bias_stats(&1, &2, favorite_team_ids)
        )

      Map.put(stats, :has_favorites, true)
    end
  end

  defp accumulate_bias_stats(pred, acc, favorite_team_ids) do
    match = pred.match

    involves_favorite =
      match.home_team_id in favorite_team_ids or
        match.away_team_id in favorite_team_ids

    correct_result = correct_result?(pred, match)
    correct_score = correct_score?(pred, match)

    if involves_favorite do
      %{
        acc
        | favorite_predictions: acc.favorite_predictions + 1,
          favorite_correct_results:
            acc.favorite_correct_results + if(correct_result, do: 1, else: 0),
          favorite_correct_scores: acc.favorite_correct_scores + if(correct_score, do: 1, else: 0)
      }
    else
      %{
        acc
        | other_predictions: acc.other_predictions + 1,
          other_correct_results: acc.other_correct_results + if(correct_result, do: 1, else: 0),
          other_correct_scores: acc.other_correct_scores + if(correct_score, do: 1, else: 0)
      }
    end
  end

  defp correct_result?(prediction, match) do
    pred_result =
      cond do
        prediction.home_score > prediction.away_score -> :home
        prediction.home_score < prediction.away_score -> :away
        true -> :draw
      end

    match_result =
      cond do
        match.home_score > match.away_score -> :home
        match.home_score < match.away_score -> :away
        true -> :draw
      end

    pred_result == match_result
  end

  defp correct_score?(prediction, match) do
    prediction.home_score == match.home_score and prediction.away_score == match.away_score
  end

  ## User Rivalries

  @doc """
  Get all rivalries for a user (both as user and as rival).
  """
  def get_user_rivalries(user_id) do
    query =
      from(ur in UserRivalry,
        where: ur.user_id == ^user_id and ur.status == "active",
        preload: [:rival]
      )

    Repo.all(query)
  end

  @doc """
  Get a specific rivalry between two users.
  """
  def get_rivalry(user_id, rival_id) do
    Repo.get_by(UserRivalry, user_id: user_id, rival_id: rival_id)
  end

  @doc """
  Get a rivalry by ID.
  """
  def get_rivalry!(id) do
    Repo.get!(UserRivalry, id) |> Repo.preload([:user, :rival])
  end

  @doc """
  Add a rival for a user.
  """
  def add_rival(user_id, rival_id) do
    %UserRivalry{}
    |> UserRivalry.changeset(%{user_id: user_id, rival_id: rival_id})
    |> Repo.insert()
  end

  @doc """
  Remove a rivalry.
  """
  def remove_rival(user_id, rival_id) do
    query =
      from(ur in UserRivalry,
        where: ur.user_id == ^user_id and ur.rival_id == ^rival_id
      )

    Repo.delete_all(query)
  end

  @doc """
  Toggle notifications for a rivalry.
  """
  def toggle_rivalry_notifications(user_id, rival_id) do
    case get_rivalry(user_id, rival_id) do
      nil ->
        {:error, :not_found}

      rivalry ->
        rivalry
        |> Ecto.Changeset.change(notifications_enabled: !rivalry.notifications_enabled)
        |> Repo.update()
    end
  end

  @doc """
  Check if user has a rivalry with another user.
  """
  def rival?(user_id, rival_id) do
    query =
      from(ur in UserRivalry,
        where: ur.user_id == ^user_id and ur.rival_id == ^rival_id and ur.status == "active"
      )

    Repo.exists?(query)
  end

  @doc """
  Get rivalry statistics between two users.
  Uses the compare_predictions resolver to calculate head-to-head stats.
  """
  def get_rivalry_stats(user_id, rival_id) do
    alias Jalka2026Web.Resolvers.FootballResolver

    comparison = FootballResolver.compare_predictions(user_id, rival_id)
    summary = comparison.summary

    %{
      user_group_points: summary.user1_group_points,
      rival_group_points: summary.user2_group_points,
      user_playoff_points: summary.user1_playoff_points,
      rival_playoff_points: summary.user2_playoff_points,
      user_total_points: summary.user1_total_points,
      rival_total_points: summary.user2_total_points,
      user_correct_results: summary.user1_correct_results,
      rival_correct_results: summary.user2_correct_results,
      user_correct_scores: summary.user1_correct_scores,
      rival_correct_scores: summary.user2_correct_scores,
      matches_user_won: summary.matches_user1_won,
      matches_rival_won: summary.matches_user2_won,
      matches_tied: summary.matches_tied,
      finished_matches_count: summary.finished_matches_count,
      total_matches_count: summary.total_matches_count
    }
  end

  @doc """
  Get all rivalries for a user with statistics included.
  """
  def get_user_rivalries_with_stats(user_id) do
    rivalries = get_user_rivalries(user_id)

    Enum.map(rivalries, fn rivalry ->
      stats = get_rivalry_stats(user_id, rivalry.rival_id)
      %{rivalry: rivalry, stats: stats}
    end)
  end

  @doc """
  Get matches where user and rival have different predictions.
  Returns upcoming matches where their predictions differ.
  """
  def get_differing_predictions(user_id, rival_id) do
    user_predictions = get_predictions_by_user(user_id)
    rival_predictions = get_predictions_by_user(rival_id)

    user_map = Map.new(user_predictions, fn p -> {p.match_id, p} end)
    rival_map = Map.new(rival_predictions, fn p -> {p.match_id, p} end)

    all_match_ids =
      (Map.keys(user_map) ++ Map.keys(rival_map))
      |> Enum.uniq()

    all_match_ids
    |> Enum.map(&build_differing_prediction(&1, user_map, rival_map))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn d -> d.match.date end)
  end

  defp build_differing_prediction(match_id, user_map, rival_map) do
    user_pred = Map.get(user_map, match_id)
    rival_pred = Map.get(rival_map, match_id)

    with {%{} = up, %{} = rp} <- {user_pred, rival_pred},
         true <- up.result != rp.result,
         false <- up.match.finished do
      %{
        match: up.match,
        user_prediction: %{
          home_score: up.home_score,
          away_score: up.away_score,
          result: up.result
        },
        rival_prediction: %{
          home_score: rp.home_score,
          away_score: rp.away_score,
          result: rp.result
        }
      }
    else
      _ -> nil
    end
  end

  @doc """
  Get rivalries where notifications are enabled.
  """
  def get_rivalries_with_notifications(user_id) do
    query =
      from(ur in UserRivalry,
        where:
          ur.user_id == ^user_id and ur.status == "active" and ur.notifications_enabled == true,
        preload: [:rival]
      )

    Repo.all(query)
  end

  ## Bracket Predictions

  @doc """
  Get all bracket predictions (winner predictions only, side IS NULL) for a user.
  """
  def get_bracket_predictions_by_user(user_id) do
    query =
      from(bp in BracketPrediction,
        where: bp.user_id == ^user_id and is_nil(bp.side),
        preload: [:team],
        order_by: [asc: bp.round, asc: bp.position]
      )

    Repo.all(query)
  end

  @doc """
  Get bracket predictions for a user, organized by round.
  Returns a map of round => list of predictions (winner predictions only).
  """
  def get_bracket_predictions_by_round(user_id) do
    predictions = get_bracket_predictions_by_user(user_id)
    Enum.group_by(predictions, & &1.round)
  end

  @doc """
  Get matchup overrides for a user, organized by round.
  Returns a map of round => list of override predictions (side IS NOT NULL).
  """
  def get_bracket_overrides_by_round(user_id) do
    query =
      from(bp in BracketPrediction,
        where: bp.user_id == ^user_id and not is_nil(bp.side),
        preload: [:team],
        order_by: [asc: bp.round, asc: bp.position]
      )

    Repo.all(query)
    |> Enum.group_by(& &1.round)
  end

  @doc """
  Get a specific bracket prediction (winner prediction, side IS NULL).
  """
  def get_bracket_prediction(user_id, round, position) do
    from(bp in BracketPrediction,
      where: bp.user_id == ^user_id and bp.round == ^round and bp.position == ^position and is_nil(bp.side)
    )
    |> Repo.one()
    |> Repo.preload(:team)
  end

  @doc """
  Get a specific matchup override (side = "a" or "b").
  """
  def get_bracket_override(user_id, round, position, side) do
    from(bp in BracketPrediction,
      where: bp.user_id == ^user_id and bp.round == ^round and bp.position == ^position and bp.side == ^side
    )
    |> Repo.one()
    |> Repo.preload(:team)
  end

  @doc """
  Set or update a bracket prediction (winner prediction).
  """
  def set_bracket_prediction(%{
        user_id: user_id,
        round: round,
        position: position,
        team_id: team_id
      }) do
    case get_bracket_prediction(user_id, round, position) do
      nil ->
        %BracketPrediction{}
        |> BracketPrediction.changeset(%{
          user_id: user_id,
          round: round,
          position: position,
          team_id: team_id
        })
        |> Repo.insert()

      prediction ->
        prediction
        |> BracketPrediction.changeset(%{team_id: team_id})
        |> Repo.update()
    end
  end

  @doc """
  Set or update a matchup override (side = "a" or "b").
  """
  def set_bracket_override(%{
        user_id: user_id,
        round: round,
        position: position,
        side: side,
        team_id: team_id
      }) do
    case get_bracket_override(user_id, round, position, side) do
      nil ->
        %BracketPrediction{}
        |> BracketPrediction.changeset(%{
          user_id: user_id,
          round: round,
          position: position,
          side: side,
          team_id: team_id
        })
        |> Repo.insert()

      prediction ->
        prediction
        |> BracketPrediction.changeset(%{team_id: team_id})
        |> Repo.update()
    end
  end

  @doc """
  Clear a bracket prediction (winner, side IS NULL).
  """
  def clear_bracket_prediction(user_id, round, position) do
    case get_bracket_prediction(user_id, round, position) do
      nil -> {:ok, nil}
      prediction -> Repo.delete(prediction)
    end
  end

  @doc """
  Clear a matchup override.
  """
  def clear_bracket_override(user_id, round, position, side) do
    case get_bracket_override(user_id, round, position, side) do
      nil -> {:ok, nil}
      prediction -> Repo.delete(prediction)
    end
  end

  @doc """
  Clear all predictions (winners and overrides) in later rounds when a team is removed from an earlier round.
  This cascades the removal through the bracket.
  """
  def cascade_bracket_removal(user_id, team_id, from_round) do
    rounds_to_clear = get_rounds_after(from_round)

    query =
      from(bp in BracketPrediction,
        where: bp.user_id == ^user_id and bp.team_id == ^team_id and bp.round in ^rounds_to_clear
      )

    Repo.delete_all(query)
  end

  defp get_rounds_after(round) do
    all_rounds = ["round_of_32", "round_of_16", "quarter_final", "semi_final", "final"]
    index = Enum.find_index(all_rounds, &(&1 == round))

    if index do
      Enum.drop(all_rounds, index + 1)
    else
      []
    end
  end

  @doc """
  Get all bracket results (actual tournament results).
  """
  def get_bracket_results() do
    comp_id = competition_id()

    query =
      from(br in BracketResult,
        where: br.competition_id == ^comp_id,
        preload: [:team],
        order_by: [asc: br.round, asc: br.position]
      )

    Repo.all(query)
  end

  @doc """
  Get bracket results organized by round.
  """
  def get_bracket_results_by_round() do
    results = get_bracket_results()
    Enum.group_by(results, & &1.round)
  end

  @doc """
  Set or update a bracket result (admin function).
  """
  def set_bracket_result(%{round: round, position: position, team_id: team_id}) do
    comp_id = competition_id()

    case Repo.get_by(BracketResult, round: round, position: position, competition_id: comp_id) do
      nil ->
        %BracketResult{}
        |> BracketResult.changeset(%{
          round: round,
          position: position,
          team_id: team_id,
          competition_id: comp_id
        })
        |> Repo.insert()

      result ->
        result
        |> BracketResult.changeset(%{team_id: team_id})
        |> Repo.update()
    end
  end

  @doc """
  Calculate bracket accuracy for a user.
  Returns a map with correct predictions per round and total accuracy.
  """
  def calculate_bracket_accuracy(user_id) do
    predictions = get_bracket_predictions_by_user(user_id)
    results = get_bracket_results()

    results_map =
      results
      |> Enum.map(fn r -> {{r.round, r.position}, r.team_id} end)
      |> Map.new()

    rounds = ["round_of_32", "round_of_16", "quarter_final", "semi_final", "final"]

    round_stats = Enum.map(rounds, &compute_round_accuracy(&1, predictions, results_map))

    total_correct = Enum.sum(Enum.map(round_stats, & &1.correct))
    total_possible = Enum.sum(Enum.map(round_stats, & &1.total))

    %{
      by_round: round_stats,
      total_correct: total_correct,
      total_possible: total_possible,
      overall_accuracy:
        if(total_possible > 0, do: total_correct / total_possible * 100, else: 0.0)
    }
  end

  defp compute_round_accuracy(round, predictions, results_map) do
    round_predictions = Enum.filter(predictions, &(&1.round == round))

    {correct, total} =
      Enum.reduce(round_predictions, {0, 0}, fn pred, {correct, total} ->
        result_team_id = Map.get(results_map, {pred.round, pred.position})

        new_correct =
          if result_team_id && result_team_id == pred.team_id do
            correct + 1
          else
            correct
          end

        # Only count if there's a result for this position
        new_total = if result_team_id, do: total + 1, else: total

        {new_correct, new_total}
      end)

    %{
      round: round,
      correct: correct,
      total: total,
      accuracy: if(total > 0, do: correct / total * 100, else: 0.0)
    }
  end

  @doc """
  Calculate bracket points for a user.
  Points increase for correct predictions in later rounds.
  """
  def calculate_bracket_points(user_id) do
    accuracy = calculate_bracket_accuracy(user_id)

    # Points per correct winner pick by round. A round's winner advances to the next stage, so the
    # value matches that stage's points in Scoring.@playoff_points (round_of_32 winner reaches the
    # last-16 = 2pt ... final winner = champion = 8pt). Kept in sync with the leaderboard scheme.
    points_per_round = %{
      "round_of_32" => 2,
      "round_of_16" => 3,
      "quarter_final" => 5,
      "semi_final" => 6,
      "final" => 8
    }

    Enum.reduce(accuracy.by_round, 0, fn round_stat, total ->
      round_points = Map.get(points_per_round, round_stat.round, 0)
      total + round_stat.correct * round_points
    end)
  end

  @doc """
  Get bracket comparison between two users.
  """
  def compare_brackets(user1_id, user2_id) do
    user1_predictions = get_bracket_predictions_by_round(user1_id)
    user2_predictions = get_bracket_predictions_by_round(user2_id)
    results = get_bracket_results_by_round()

    rounds = ["round_of_32", "round_of_16", "quarter_final", "semi_final", "final"]

    comparison =
      Enum.map(rounds, fn round ->
        user1_round = Map.get(user1_predictions, round, [])
        user2_round = Map.get(user2_predictions, round, [])
        results_round = Map.get(results, round, [])

        positions = BracketPrediction.positions_for_round(round)

        position_comparison =
          Enum.map(1..positions, fn pos ->
            user1_pred = Enum.find(user1_round, &(&1.position == pos))
            user2_pred = Enum.find(user2_round, &(&1.position == pos))
            result = Enum.find(results_round, &(&1.position == pos))

            %{
              position: pos,
              user1_team: if(user1_pred, do: user1_pred.team, else: nil),
              user2_team: if(user2_pred, do: user2_pred.team, else: nil),
              actual_team: if(result, do: result.team, else: nil),
              user1_correct: result && user1_pred && user1_pred.team_id == result.team_id,
              user2_correct: result && user2_pred && user2_pred.team_id == result.team_id,
              both_same: user1_pred && user2_pred && user1_pred.team_id == user2_pred.team_id
            }
          end)

        %{
          round: round,
          round_display: BracketPrediction.round_display_name(round),
          positions: position_comparison
        }
      end)

    user1_points = calculate_bracket_points(user1_id)
    user2_points = calculate_bracket_points(user2_id)

    %{
      rounds: comparison,
      user1_points: user1_points,
      user2_points: user2_points
    }
  end
end

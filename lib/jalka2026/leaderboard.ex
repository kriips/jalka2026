defmodule Jalka2026.Leaderboard do
  use GenServer

  require Logger

  alias Jalka2026Web.Resolvers.{FootballResolver, AccountsResolver}
  alias Jalka2026.Football
  alias Jalka2026.Accounts.User
  alias Jalka2026.Scoring
  alias Jalka2026.Streak
  alias Jalka2026.Badges
  alias Jalka2026.Telemetry.Events, as: TelemetryEvents

  @pubsub Jalka2026.PubSub
  @topic "leaderboard:updates"
  @circuit_breaker_timeout 500

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    state = %{
      leaderboard: [],
      recalculating: false,
      task_ref: nil,
      waiting_callers: []
    }

    {:ok, state, {:continue, :populate_cache}}
  end

  @impl true
  def handle_continue(:populate_cache, state) do
    if Application.get_env(:jalka2026, :environment) == :test do
      # Skip warm-up in test — Ecto sandbox doesn't extend to spawned tasks
      {:noreply, state}
    else
      {task_ref, new_state} = start_recalculation(state)
      {:noreply, %{new_state | task_ref: task_ref, recalculating: true}}
    end
  end

  @doc """
  Subscribe to leaderboard updates via PubSub.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
  end

  @doc """
  Returns the current cached leaderboard.
  """
  def get_leaderboard, do: GenServer.call(__MODULE__, :get_leaderboard)

  @doc """
  Synchronously recalculates the leaderboard. If recalculation takes longer
  than #{@circuit_breaker_timeout}ms, returns stale cached data instead of blocking.
  The recalculation continues in the background and the cache will be updated
  when it completes.
  """
  def recalc_leaderboard, do: GenServer.call(__MODULE__, :recalc_leaderboard)

  @doc """
  Asynchronously recalculates the leaderboard. Use this when you don't need
  to wait for the result (e.g., after user registration).
  """
  def recalc_leaderboard_async, do: GenServer.cast(__MODULE__, :recalc_leaderboard_async)

  # --- Callbacks ---

  @impl true
  def handle_call(:get_leaderboard, _from, state) do
    {:reply, state.leaderboard, state}
  end

  def handle_call(:recalc_leaderboard, from, %{recalculating: true} = state) do
    # A recalculation is already in progress — add caller to waiting list
    # with a timer for circuit breaker timeout
    timer_ref = Process.send_after(self(), {:circuit_breaker_timeout, from}, @circuit_breaker_timeout)
    waiting = [{from, timer_ref} | state.waiting_callers]
    {:noreply, %{state | waiting_callers: waiting}}
  end

  def handle_call(:recalc_leaderboard, from, state) do
    # No recalculation in progress — start one and wait
    {task_ref, new_state} = start_recalculation(state)
    timer_ref = Process.send_after(self(), {:circuit_breaker_timeout, from}, @circuit_breaker_timeout)
    waiting = [{from, timer_ref} | new_state.waiting_callers]
    {:noreply, %{new_state | task_ref: task_ref, recalculating: true, waiting_callers: waiting}}
  end

  @impl true
  def handle_cast(:recalc_leaderboard_async, %{recalculating: true} = state) do
    # Already recalculating, skip
    {:noreply, state}
  end

  def handle_cast(:recalc_leaderboard_async, state) do
    {task_ref, new_state} = start_recalculation(state)
    {:noreply, %{new_state | task_ref: task_ref, recalculating: true}}
  end

  @impl true
  def handle_info({:circuit_breaker_timeout, from}, state) do
    # Circuit breaker fired — reply with stale data to the waiting caller
    case List.keytake(state.waiting_callers, from, 0) do
      {{^from, _timer_ref}, remaining} ->
        GenServer.reply(from, state.leaderboard)
        {:noreply, %{state | waiting_callers: remaining}}

      nil ->
        # Already replied (task completed before timeout)
        {:noreply, state}
    end
  end

  def handle_info({ref, {:ok, new_leaderboard}}, %{task_ref: ref} = state) do
    # Task completed successfully — flush the DOWN message
    Process.demonitor(ref, [:flush])

    changes = calculate_changes(state.leaderboard, new_leaderboard)
    broadcast_update(new_leaderboard, changes)

    # Reply to all waiting callers with fresh data and cancel their timers
    Enum.each(state.waiting_callers, fn {from, timer_ref} ->
      Process.cancel_timer(timer_ref)
      GenServer.reply(from, new_leaderboard)
    end)

    {:noreply, %{state | leaderboard: new_leaderboard, recalculating: false, task_ref: nil, waiting_callers: []}}
  end

  def handle_info({ref, {:error, reason}}, %{task_ref: ref} = state) do
    # Task failed — flush the DOWN message and keep stale data
    Process.demonitor(ref, [:flush])
    Logger.warning("Leaderboard recalculation failed: #{inspect(reason)}")

    # Reply to waiting callers with stale data
    Enum.each(state.waiting_callers, fn {from, timer_ref} ->
      Process.cancel_timer(timer_ref)
      GenServer.reply(from, state.leaderboard)
    end)

    {:noreply, %{state | recalculating: false, task_ref: nil, waiting_callers: []}}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{task_ref: ref} = state) do
    # Task process crashed
    Logger.warning("Leaderboard recalculation task crashed: #{inspect(reason)}")

    # Reply to waiting callers with stale data
    Enum.each(state.waiting_callers, fn {from, timer_ref} ->
      Process.cancel_timer(timer_ref)
      GenServer.reply(from, state.leaderboard)
    end)

    {:noreply, %{state | recalculating: false, task_ref: nil, waiting_callers: []}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # --- Private helpers ---

  defp start_recalculation(state) do
    task =
      Task.async(fn ->
        try do
          {:ok, recalculate_leaderboard()}
        rescue
          error ->
            {:error, error}
        end
      end)

    {task.ref, state}
  end

  defp broadcast_update(leaderboard, changes) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:leaderboard_updated, leaderboard, changes})
  end

  defp calculate_changes(old_leaderboard, new_leaderboard) do
    old_map = Map.new(old_leaderboard, fn {id, rank, _name, _gp, _pp, _bp, _cs, _ls, points} -> {id, {rank, points}} end)

    Enum.reduce(new_leaderboard, %{}, fn {id, new_rank, _name, _gp, _pp, _bp, _cs, _ls, new_points}, acc ->
      case Map.get(old_map, id) do
        nil ->
          Map.put(acc, id, %{rank_change: :new, points_change: new_points})

        {old_rank, old_points} ->
          rank_change = old_rank - new_rank
          points_change = new_points - old_points

          if rank_change != 0 or points_change != 0 do
            Map.put(acc, id, %{rank_change: rank_change, points_change: points_change})
          else
            acc
          end
      end
    end)
  end

  defp recalculate_leaderboard() do
    finished_matches = FootballResolver.list_finished_matches()
    playoff_results = FootballResolver.list_playoff_results()
    users = AccountsResolver.list_users()

    # Bulk-load all predictions in single queries (avoids N+1)
    all_predictions = Football.get_all_predictions_indexed()
    all_predictions_by_user = Football.get_all_predictions_by_user()
    all_playoff_predictions = Football.get_all_playoff_predictions_indexed()

    # Recalculate streaks and badges with shared data to avoid duplicate queries
    streaks = Streak.recalculate_all_streaks(users, finished_matches, all_predictions_by_user)
    Badges.recalculate_all_badges(users, finished_matches, playoff_results, all_predictions_by_user)

    metadata = %{
      user_count: length(users),
      match_count: length(finished_matches),
      playoff_result_count: length(playoff_results)
    }

    TelemetryEvents.span_leaderboard_calculation(metadata, fn ->
      users
      |> Enum.map(&calculate_points(&1, finished_matches, all_predictions))
      |> Enum.map(&calculate_playoff_points(&1, playoff_results, all_playoff_predictions))
      |> Enum.map(&add_streak_data(&1, streaks))
      |> Enum.sort(fn {_id1, _name1, _gpoints1, _ppoints1, _bonus1, _current1, _longest1, points1},
                      {_id2, _name2, _gpoints2, _ppoints2, _bonus2, _current2, _longest2, points2} ->
        points1 >= points2
      end)
      |> add_rank()
    end)
  end

  defp calculate_playoff_points({user_id, user_name, group_points}, playoff_results, all_playoff_predictions) do
    playoff_predictions = Map.get(all_playoff_predictions, user_id, %{})
    playoff_points = Scoring.total_playoff_points(playoff_results, playoff_predictions)
    {user_id, user_name, group_points, playoff_points}
  end

  defp add_streak_data({user_id, user_name, group_points, playoff_points}, streaks) do
    streak_data = Map.get(streaks, user_id, %{current_streak: 0, longest_streak: 0, bonus_points: 0})
    bonus_points = streak_data.bonus_points
    current_streak = streak_data.current_streak
    longest_streak = streak_data.longest_streak
    total_points = group_points + playoff_points + bonus_points

    {user_id, user_name, group_points, playoff_points, bonus_points, current_streak, longest_streak, total_points}
  end

  defp calculate_points(%User{} = user, finished_matches, all_predictions) do
    points =
      finished_matches
      |> Enum.reduce(0, fn finished_match, points ->
        group_prediction =
          Map.get(all_predictions, {user.id, finished_match.id})
          |> sanitize()

        points + Scoring.group_match_points(finished_match, group_prediction)
      end)

    {user.id, user.name, points}
  end


  defp sanitize(nil) do
    nil
  end

  defp sanitize(group_prediction) do
    if group_prediction.home_score && group_prediction.away_score &&
         is_nil(group_prediction.result) do
      FootballResolver.change_prediction_score(%{
        match_id: group_prediction.match_id,
        user_id: group_prediction.user_id,
        score: {group_prediction.home_score, group_prediction.away_score}
      })
    else
      group_prediction
    end
  end

  defp add_rank(users, rank \\ 1, index \\ 1, acc \\ [])

  defp add_rank([{id, name, gpoints, ppoints, bpoints, current_streak, longest_streak, points} | users], rank, index, acc) do
    add_rank(users, rank, index + 1, points, acc ++ [{id, rank, name, gpoints, ppoints, bpoints, current_streak, longest_streak, points}])
  end

  defp add_rank([], _rank, _index, []) do
    []
  end

  defp add_rank([{id, name, gpoints, ppoints, bpoints, current_streak, longest_streak, points} | users], rank, index, prev_points, acc) do
    new_rank =
      if points == prev_points do
        rank
      else
        index
      end

    add_rank(
      users,
      new_rank,
      index + 1,
      points,
      acc ++ [{id, new_rank, name, gpoints, ppoints, bpoints, current_streak, longest_streak, points}]
    )
  end

  defp add_rank([], _rank, _index, _prev_points, acc) do
    acc
  end
end

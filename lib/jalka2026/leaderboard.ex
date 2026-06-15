defmodule Jalka2026.Leaderboard do
  @moduledoc """
  Cached leaderboard GenServer.

  Exposes a ranked list of `%Jalka2026.Leaderboard.Entry{}` structs
  sorted by total points (descending). The leaderboard is recalculated
  asynchronously via `Task.async/1` and cached in GenServer state.

  ## Public API

  - `get_leaderboard/0` — returns `[Entry.t()]`
  - `recalc_leaderboard/0` — synchronous recalculation (circuit-breaker: #{500}ms)
  - `recalc_leaderboard_async/0` — fire-and-forget recalculation
  - `subscribe/0` — subscribe to `:leaderboard_updated` broadcasts
  """

  use GenServer

  require Logger

  alias Jalka2026.Accounts.User
  alias Jalka2026.Badges
  alias Jalka2026.Football
  alias Jalka2026.Football.Qualifiers
  alias Jalka2026.Leaderboard.Entry
  alias Jalka2026.Scoring
  alias Jalka2026.Streak
  alias Jalka2026.Telemetry.Events, as: TelemetryEvents
  alias Jalka2026Web.Resolvers.AccountsResolver
  alias Jalka2026Web.Resolvers.FootballResolver

  @type leaderboard :: [Entry.t()]

  @pubsub Jalka2026.PubSub
  @topic "leaderboard:updates"
  @circuit_breaker_timeout 500

  @spec start_link(keyword()) :: GenServer.on_start()
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
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
  end

  @doc """
  Returns the current cached leaderboard as a list of `%Entry{}` structs.
  """
  @spec get_leaderboard() :: leaderboard()
  def get_leaderboard, do: GenServer.call(__MODULE__, :get_leaderboard)

  @doc """
  Synchronously recalculates the leaderboard. If recalculation takes longer
  than #{@circuit_breaker_timeout}ms, returns stale cached data instead of blocking.
  The recalculation continues in the background and the cache will be updated
  when it completes.
  """
  @spec recalc_leaderboard() :: leaderboard()
  def recalc_leaderboard, do: GenServer.call(__MODULE__, :recalc_leaderboard)

  @doc """
  Asynchronously recalculates the leaderboard. Use this when you don't need
  to wait for the result (e.g., after user registration).
  """
  @spec recalc_leaderboard_async() :: :ok
  def recalc_leaderboard_async, do: GenServer.cast(__MODULE__, :recalc_leaderboard_async)

  # --- Callbacks ---

  @impl true
  def handle_call(:get_leaderboard, _from, state) do
    {:reply, state.leaderboard, state}
  end

  def handle_call(:recalc_leaderboard, from, %{recalculating: true} = state) do
    # A recalculation is already in progress — add caller to waiting list
    # with a timer for circuit breaker timeout
    timer_ref =
      Process.send_after(self(), {:circuit_breaker_timeout, from}, @circuit_breaker_timeout)

    waiting = [{from, timer_ref} | state.waiting_callers]
    {:noreply, %{state | waiting_callers: waiting}}
  end

  def handle_call(:recalc_leaderboard, from, state) do
    # No recalculation in progress — start one and wait
    {task_ref, new_state} = start_recalculation(state)

    timer_ref =
      Process.send_after(self(), {:circuit_breaker_timeout, from}, @circuit_breaker_timeout)

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

    {:noreply,
     %{
       state
       | leaderboard: new_leaderboard,
         recalculating: false,
         task_ref: nil,
         waiting_callers: []
     }}
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

  # A failed badge write must never take down the leaderboard server.
  defp award_rank_badges(new_leaderboard, old_leaderboard) do
    Badges.award_rank_badges(new_leaderboard, old_leaderboard)
  rescue
    error -> Logger.warning("Rank badge award failed: #{inspect(error)}")
  end

  defp calculate_changes(old_leaderboard, new_leaderboard) do
    old_map =
      Map.new(old_leaderboard, fn %Entry{user_id: id, rank: rank, total_points: points} ->
        {id, {rank, points}}
      end)

    Enum.reduce(new_leaderboard, %{}, fn %Entry{
                                           user_id: id,
                                           rank: new_rank,
                                           total_points: new_points
                                         },
                                         acc ->
      entry_change(acc, id, new_rank, new_points, Map.get(old_map, id))
    end)
  end

  defp entry_change(acc, id, _new_rank, new_points, nil),
    do: Map.put(acc, id, %{rank_change: :new, points_change: new_points})

  defp entry_change(acc, id, new_rank, new_points, {old_rank, old_points}) do
    rank_change = old_rank - new_rank
    points_change = new_points - old_points

    if rank_change != 0 or points_change != 0,
      do: Map.put(acc, id, %{rank_change: rank_change, points_change: points_change}),
      else: acc
  end

  defp recalculate_leaderboard() do
    # The currently-cached leaderboard is the previous ranking — used to detect
    # rank climbs for the "climber" badge below.
    previous_leaderboard = get_leaderboard()

    {finished_matches, playoff_results, users, all_predictions, all_predictions_by_user,
     all_playoff_predictions} =
      TelemetryEvents.span_leaderboard_data_load(%{source: :recalculate_leaderboard}, fn ->
        finished_matches = FootballResolver.list_finished_matches()
        playoff_results = FootballResolver.list_playoff_results()
        users = AccountsResolver.list_users()

        # Bulk-load all predictions in single queries (avoids N+1)
        all_predictions = Football.get_all_predictions_indexed()
        all_predictions_by_user = Football.get_all_predictions_by_user()
        all_playoff_predictions = Football.get_all_playoff_predictions_indexed()

        {finished_matches, playoff_results, users, all_predictions, all_predictions_by_user,
         all_playoff_predictions}
      end)

    # Recalculate streaks and badges with shared data to avoid duplicate queries
    streaks = Streak.recalculate_all_streaks(users, finished_matches, all_predictions_by_user)

    Badges.recalculate_all_badges(
      users,
      finished_matches,
      playoff_results,
      all_predictions_by_user
    )

    # Users who didn't finish their group-stage predictions before the
    # competition started are not ranked. Streaks and badges above are still
    # recalculated for everyone so their profile stats keep working.
    eligible_users =
      Enum.filter(users, &group_predictions_complete?(&1, all_predictions_by_user))

    metadata = %{
      user_count: length(eligible_users),
      match_count: length(finished_matches),
      playoff_result_count: length(playoff_results)
    }

    # Teams that actually reached the round of 32 (empty until the group stage is complete).
    # Scores the "32 parimat" stage against each user's predicted qualifiers + R32 swaps.
    actual_last_32 = Qualifiers.actual_last_32()

    # Bulk-compute every user's predicted last-32 list ONCE (only once there's an actual last-32 to
    # score against) — avoids the per-user N+1 in the user loop below.
    predicted_last_32_by_user =
      if actual_last_32 == [], do: %{}, else: Qualifiers.all_predicted_last_32()

    new_leaderboard =
      TelemetryEvents.span_leaderboard_calculation(metadata, fn ->
        eligible_users
        |> Enum.map(&calculate_points(&1, finished_matches, all_predictions))
        |> Enum.map(
          &calculate_playoff_points(
            &1,
            playoff_results,
            all_playoff_predictions,
            actual_last_32,
            predicted_last_32_by_user
          )
        )
        |> Enum.map(&add_streak_data(&1, streaks))
        |> Enum.sort_by(& &1.total_points, :desc)
        |> add_rank()
      end)

    # Rank-based badges run here (inside the recalc task, alongside the other
    # badge writes) so the DB work shares the same process and never races the
    # GenServer's reply handling.
    award_rank_badges(new_leaderboard, previous_leaderboard)

    new_leaderboard
  end

  # A user has finished the group stage when they predicted every group match
  # (72 in production, configured via :leaderboard_required_predictions).
  defp group_predictions_complete?(%User{id: user_id}, all_predictions_by_user) do
    required = Application.get_env(:jalka2026, :leaderboard_required_predictions, 0)
    map_size(Map.get(all_predictions_by_user, user_id, %{})) >= required
  end

  defp calculate_playoff_points(
         %{user_id: user_id} = acc,
         playoff_results,
         all_playoff_predictions,
         actual_last_32,
         predicted_last_32_by_user
       ) do
    playoff_predictions = Map.get(all_playoff_predictions, user_id, %{})
    phase_points = Scoring.total_playoff_points(playoff_results, playoff_predictions)

    # "32 parimat" stage: 0 until the group stage completes (no last-32 determined yet).
    last_32_points =
      if actual_last_32 == [] do
        0
      else
        predicted = Map.get(predicted_last_32_by_user, user_id, [])
        Scoring.last_32_points(predicted, actual_last_32)
      end

    Map.put(acc, :playoff_points, phase_points + last_32_points)
  end

  defp add_streak_data(%{user_id: user_id, group_points: gp, playoff_points: pp} = acc, streaks) do
    streak_data =
      Map.get(streaks, user_id, %{current_streak: 0, longest_streak: 0})

    acc
    |> Map.put(:current_streak, streak_data.current_streak)
    |> Map.put(:longest_streak, streak_data.longest_streak)
    |> Map.put(:total_points, gp + pp)
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

    %{user_id: user.id, name: user.name, group_points: points}
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

  defp add_rank(rows) do
    rows
    |> Enum.with_index(1)
    |> Enum.reduce({[], nil, 1}, fn {row, index}, {acc, prev_points, current_rank} ->
      rank = if row.total_points == prev_points, do: current_rank, else: index
      entry = Entry.new(Map.put(row, :rank, rank))
      {[entry | acc], row.total_points, rank}
    end)
    |> elem(0)
    |> Enum.reverse()
  end
end

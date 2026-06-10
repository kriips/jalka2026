defmodule Jalka2026Web.UserPredictionLive.Playoffs do
  use Jalka2026Web, :live_view

  alias Jalka2026.Football
  alias Jalka2026.Football.{BracketPrediction, BracketSeeding, GroupScenarios, ThirdPlaceSeeding}
  alias Jalka2026.PredictionSync
  alias Jalka2026Web.TelemetryHooks

  @rounds ["round_of_32", "round_of_16", "quarter_final", "semi_final", "final"]

  @impl true
  def mount(_params, _session, socket) do
    TelemetryHooks.with_mount_telemetry(__MODULE__, socket, fn ->
      user_id = socket.assigns.current_user.id

      if connected?(socket) do
        PredictionSync.subscribe(user_id)
      end

      socket =
        socket
        |> assign(
          prediction_deadline: Application.get_env(:jalka2026, :prediction_deadline),
          predictions_open: Jalka2026Web.LiveHelpers.predictions_open?(),
          swap_slot: nil
        )
        |> load_bracket(user_id)

      {:ok, socket}
    end)
  end

  @impl true
  def handle_params(params, _uri, socket) do
    stage = Map.get(params, "stage", "round_of_32")

    stage =
      if stage in @rounds do
        stage
      else
        "round_of_32"
      end

    stage_index = Enum.find_index(@rounds, &(&1 == stage))

    prev_stage =
      if stage_index > 0 do
        Enum.at(@rounds, stage_index - 1)
      end

    next_stage =
      if stage_index < length(@rounds) - 1 do
        Enum.at(@rounds, stage_index + 1)
      end

    current_round = Enum.find(socket.assigns.rounds, &(&1.round == stage))

    {:noreply,
     assign(socket,
       current_stage: stage,
       current_round: current_round,
       prev_stage: prev_stage,
       next_stage: next_stage,
       stage_index: stage_index,
       stage_count: length(@rounds)
     )}
  end

  @impl true
  def handle_event("predictions_locked", _params, socket) do
    {:noreply,
     socket
     |> Phoenix.LiveView.put_flash(:error, "Ennustamine on suletud - turniir on alanud")
     |> Phoenix.LiveView.redirect(to: "/")}
  end

  @impl true
  def handle_event("reset-playoff-bracket-seeding", _params, socket) do
    with :ok <- ensure_predictions_open() do
      reset_playoff_bracket(socket)
    else
      :closed -> predictions_closed_reply(socket)
    end
  end

  @impl true
  def handle_event(
        "select-winner",
        %{"round" => round, "position" => pos, "team-id" => team_id_str},
        socket
      ) do
    with :ok <- ensure_predictions_open(),
         :ok <- check_playoff_prediction_rate(socket) do
      user_id = socket.assigns.current_user.id
      team_id = String.to_integer(team_id_str)
      position = String.to_integer(pos)

      set_winner_pick(user_id, round, position, team_id)

      {:noreply, reload_current_round(socket, user_id)}
    else
      :closed -> predictions_closed_reply(socket)
      {:error, :rate_limited} -> rate_limited_reply(socket)
    end
  end

  @impl true
  def handle_event("open-swap", %{"round" => round, "position" => pos} = params, socket) do
    position = String.to_integer(pos)
    side = Map.get(params, "side")

    swap_slot =
      if side do
        {round, position, side}
      else
        {round, position}
      end

    # Toggle: if already open on same slot, close it
    swap_slot = if socket.assigns.swap_slot == swap_slot, do: nil, else: swap_slot

    {:noreply, assign(socket, swap_slot: swap_slot)}
  end

  @impl true
  def handle_event("close-swap", _params, socket) do
    {:noreply, assign(socket, swap_slot: nil)}
  end

  @impl true
  def handle_event(
        "swap-team",
        %{"round" => round, "position" => pos, "team-id" => team_id_str} = params,
        socket
      ) do
    with :ok <- ensure_predictions_open(),
         :ok <- check_playoff_prediction_rate(socket) do
      user_id = socket.assigns.current_user.id
      team_id = String.to_integer(team_id_str)
      position = String.to_integer(pos)

      swap_team(socket, user_id, round, position, team_id, Map.get(params, "side"))

      {:noreply, reload_current_round(socket, user_id)}
    else
      :closed -> predictions_closed_reply(socket)
      {:error, :rate_limited} -> rate_limited_reply(socket, clear_swap: true)
    end
  end

  @impl true
  def handle_event("clear-winner", %{"round" => round, "position" => pos}, socket) do
    if Jalka2026Web.LiveHelpers.predictions_open?() do
      user_id = socket.assigns.current_user.id
      position = String.to_integer(pos)

      # Get team before clearing for cascade
      case Football.get_bracket_prediction(user_id, round, position) do
        nil ->
          :ok

        prediction when not is_nil(prediction.team_id) ->
          Football.cascade_bracket_removal(user_id, prediction.team_id, round)
          sync_to_playoff_prediction(user_id, prediction.team_id, round, false)

        _ ->
          :ok
      end

      Football.clear_bracket_prediction(user_id, round, position)

      socket = load_bracket(socket, user_id)

      current_round =
        Enum.find(socket.assigns.rounds, &(&1.round == socket.assigns.current_stage))

      {:noreply, assign(socket, current_round: current_round, swap_slot: nil)}
    else
      {:noreply,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Ennustamine on suletud - turniir on alanud")
       |> Phoenix.LiveView.redirect(to: "/")}
    end
  end

  defp ensure_predictions_open do
    if Jalka2026Web.LiveHelpers.predictions_open?(), do: :ok, else: :closed
  end

  defp check_playoff_prediction_rate(socket) do
    Jalka2026Web.LiveRateLimiter.check_playoff_prediction_rate(socket.assigns.current_user.id)
  end

  defp reset_playoff_bracket(socket) do
    user_id = socket.assigns.current_user.id

    case Football.reset_playoff_bracket_to_official(user_id) do
      {:ok, _changes} ->
        PredictionSync.broadcast_playoff_bracket_reset(user_id, self())

        {:noreply,
         socket
         |> reload_current_round(user_id)
         |> Phoenix.LiveView.put_flash(
           :info,
           "Play-off'i tabel lähtestati ametliku asetuse järgi. Tee play-off'i valikud uuesti."
         )}

      {:error, _step, _reason, _changes} ->
        {:noreply,
         socket
         |> Phoenix.LiveView.put_flash(
           :error,
           "Play-off'i tabeli lähtestamine ebaõnnestus. Proovi uuesti."
         )}
    end
  end

  defp set_winner_pick(user_id, round, position, team_id) do
    maybe_remove_replaced_winner(user_id, round, position, team_id)

    Football.set_bracket_prediction(%{
      user_id: user_id,
      round: round,
      position: position,
      team_id: team_id
    })

    sync_to_playoff_prediction(user_id, team_id, round, true)
    broadcast_playoff_prediction(user_id, team_id, round, true)
  end

  defp maybe_remove_replaced_winner(user_id, round, position, new_team_id) do
    case Football.get_bracket_prediction(user_id, round, position) do
      %{team_id: old_team_id} when not is_nil(old_team_id) and old_team_id != new_team_id ->
        Football.cascade_bracket_removal(user_id, old_team_id, round)
        sync_to_playoff_prediction(user_id, old_team_id, round, false)

      _ ->
        :ok
    end
  end

  defp swap_team(socket, user_id, round, position, team_id, nil) do
    set_winner_pick(user_id, round, position, team_id)
    socket
  end

  defp swap_team(socket, user_id, round, position, team_id, side) do
    old_team_id = current_slot_team_id(socket, position, side)
    maybe_clear_swapped_out_winner(user_id, round, position, old_team_id)

    Football.set_bracket_override(%{
      user_id: user_id,
      round: round,
      position: position,
      side: side,
      team_id: team_id
    })

    socket
  end

  defp current_slot_team_id(socket, position, side) do
    case Enum.find(socket.assigns.current_round.slots, &(&1.position == position)) do
      nil ->
        nil

      slot ->
        team = if side == "a", do: slot.team_a, else: slot.team_b
        team && team.id
    end
  end

  defp maybe_clear_swapped_out_winner(_user_id, _round, _position, nil), do: :ok

  defp maybe_clear_swapped_out_winner(user_id, round, position, old_team_id) do
    case Football.get_bracket_prediction(user_id, round, position) do
      %{team_id: ^old_team_id} ->
        Football.cascade_bracket_removal(user_id, old_team_id, round)
        sync_to_playoff_prediction(user_id, old_team_id, round, false)
        Football.clear_bracket_prediction(user_id, round, position)

      _ ->
        :ok
    end
  end

  defp broadcast_playoff_prediction(user_id, team_id, round, include) do
    PredictionSync.broadcast_playoff_prediction(
      user_id,
      team_id,
      round_to_phase(round),
      include,
      self()
    )
  end

  defp reload_current_round(socket, user_id) do
    socket = load_bracket(socket, user_id)
    current_round = Enum.find(socket.assigns.rounds, &(&1.round == socket.assigns.current_stage))

    assign(socket, current_round: current_round, swap_slot: nil)
  end

  defp predictions_closed_reply(socket) do
    {:noreply,
     socket
     |> Phoenix.LiveView.put_flash(:error, "Ennustamine on suletud - turniir on alanud")
     |> Phoenix.LiveView.redirect(to: "/")}
  end

  defp rate_limited_reply(socket, opts \\ []) do
    socket = Phoenix.LiveView.put_flash(socket, :error, "Liiga palju muudatusi. Oota veidi.")

    socket =
      if Keyword.get(opts, :clear_swap, false) do
        assign(socket, swap_slot: nil)
      else
        socket
      end

    {:noreply, socket}
  end

  # Handle prediction sync from other devices
  @impl true
  def handle_info(
        {:prediction_sync, :playoff_prediction_changed, %{source_pid: source_pid}},
        socket
      )
      when source_pid != self() do
    socket = load_bracket(socket, socket.assigns.current_user.id)
    current_round = Enum.find(socket.assigns.rounds, &(&1.round == socket.assigns.current_stage))
    {:noreply, assign(socket, current_round: current_round)}
  end

  def handle_info(
        {:prediction_sync, :playoff_prediction_changed, %{source_pid: source_pid}},
        socket
      )
      when source_pid == self() do
    {:noreply, socket}
  end

  # Another device reset the playoff bracket — reload to pick up the cleared
  # picks and the switched seeding version
  def handle_info({:prediction_sync, :playoff_bracket_reset, %{source_pid: source_pid}}, socket)
      when source_pid != self() do
    socket = load_bracket(socket, socket.assigns.current_user.id)
    current_round = Enum.find(socket.assigns.rounds, &(&1.round == socket.assigns.current_stage))
    {:noreply, assign(socket, current_round: current_round, swap_slot: nil)}
  end

  def handle_info({:prediction_sync, :playoff_bracket_reset, %{source_pid: source_pid}}, socket)
      when source_pid == self() do
    {:noreply, socket}
  end

  # When group predictions change, re-seed the R32
  def handle_info({:prediction_sync, :group_prediction_changed, _data}, socket) do
    socket = load_bracket(socket, socket.assigns.current_user.id)
    current_round = Enum.find(socket.assigns.rounds, &(&1.round == socket.assigns.current_stage))
    {:noreply, assign(socket, current_round: current_round)}
  end

  # --- Private: Load bracket data ---

  defp load_bracket(socket, user_id) do
    playoff_bracket_version = Football.get_playoff_bracket_version(user_id)

    # Get predicted group standings
    all_standings = GroupScenarios.get_all_predicted_standings(user_id)

    # Build standings map: %{"A" => [team1, team2, team3, team4], ...}
    standings_teams = build_standings_team_map(all_standings)

    # Determine which 3rd place teams qualify
    third_place_info = build_third_place_info(all_standings)
    qualifying_third_groups = third_place_info.qualifying_groups

    # Get seeding for 3rd place teams
    seeding =
      if length(qualifying_third_groups) == 8 do
        ThirdPlaceSeeding.get_seeding(Enum.map(qualifying_third_groups, &String.to_atom/1))
      end

    # Resolve R32 matchups to actual teams
    r32_matchups =
      resolve_matchups(
        standings_teams,
        qualifying_third_groups,
        seeding,
        third_place_info,
        playoff_bracket_version
      )

    # Get existing bracket predictions and matchup overrides
    predictions_by_round = Football.get_bracket_predictions_by_round(user_id)
    overrides_by_round = Football.get_bracket_overrides_by_round(user_id)

    # Get all tournament teams for swap candidates
    all_tournament_teams = Football.get_teams()

    # Build bracket structure for display
    rounds =
      build_rounds(
        r32_matchups,
        predictions_by_round,
        overrides_by_round,
        all_tournament_teams,
        playoff_bracket_version
      )

    # Count progress
    total_slots = 16 + 8 + 4 + 2 + 1

    filled =
      Enum.reduce(rounds, 0, fn round_data, acc ->
        acc + Enum.count(round_data.slots, & &1.predicted_team)
      end)

    predictions_done = if filled == total_slots, do: nil, else: "button-outline"

    if filled == total_slots do
      Jalka2026.Leaderboard.recalc_leaderboard()
    end

    assign(socket,
      rounds: rounds,
      r32_matchups: r32_matchups,
      third_place_info: third_place_info,
      playoff_bracket_version: playoff_bracket_version,
      legacy_playoff_bracket: playoff_bracket_version == BracketSeeding.legacy_version(),
      progress: filled,
      total_slots: total_slots,
      predictions_done: predictions_done,
      all_standings_ready: map_size(all_standings) == 12
    )
  end

  defp build_standings_team_map(all_standings) do
    Map.new(all_standings, fn {group, standings} ->
      {group, Enum.map(standings, & &1.team)}
    end)
  end

  defp build_third_place_info(all_standings) do
    # Get 3rd place team from each group with their stats
    third_place_entries =
      all_standings
      |> Enum.map(fn {group, standings} ->
        case Enum.at(standings, 2) do
          nil -> nil
          entry -> Map.put(entry, :group, group)
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Sort by points desc, goal_difference desc, goals_for desc
    sorted =
      third_place_entries
      |> Enum.sort_by(&{-&1.points, -&1.goal_difference, -&1.goals_for})

    qualifying = Enum.take(sorted, 8)
    qualifying_groups = qualifying |> Enum.map(& &1.group) |> Enum.sort()

    %{
      all_third_place: sorted,
      qualifying: qualifying,
      qualifying_groups: qualifying_groups,
      eliminated: Enum.drop(sorted, 8)
    }
  end

  defp resolve_matchups(
         standings_teams,
         qualifying_third_groups,
         seeding,
         third_place_info,
         playoff_bracket_version
       ) do
    r32_structure = BracketSeeding.r32_structure(playoff_bracket_version)

    # Build third place lookup from seeding map or fallback
    third_lookup =
      build_third_lookup(standings_teams, qualifying_third_groups, seeding, third_place_info)

    Enum.map(r32_structure, fn {pos, home_seed, away_seed} ->
      home = resolve_seed(home_seed, standings_teams, third_lookup)
      away = resolve_seed(away_seed, standings_teams, third_lookup)
      %{position: pos, home: home, away: away}
    end)
  end

  # Build third-place lookup from the seeding map (when available)
  defp build_third_lookup(standings_teams, _qualifying_groups, seeding, _third_place_info)
       when is_map(seeding) do
    # Seeding map: %{a: :E, b: :J, ...} means "winner of group A faces 3rd-place from group E"
    # Map from slot atoms (:vs_1A, :vs_1B, ...) to the seeding key (:a, :b, ...)
    slot_to_key = %{
      vs_1A: :a,
      vs_1B: :b,
      vs_1D: :d,
      vs_1E: :e,
      vs_1G: :g,
      vs_1I: :i,
      vs_1K: :k,
      vs_1L: :l
    }

    Map.new(slot_to_key, fn {slot, key} ->
      case Map.get(seeding, key) do
        nil ->
          {slot, nil}

        group_atom ->
          group = group_atom |> Atom.to_string() |> String.upcase()
          {slot, get_team_at(standings_teams, group, 2)}
      end
    end)
  end

  # Fallback when seeding combination is not in the lookup table:
  # Assign qualifying 3rd-place teams to slots in sorted order
  defp build_third_lookup(standings_teams, qualifying_groups, _seeding, third_place_info)
       when is_list(qualifying_groups) and length(qualifying_groups) == 8 do
    slots = [:vs_1A, :vs_1B, :vs_1D, :vs_1E, :vs_1G, :vs_1I, :vs_1K, :vs_1L]

    # Use the qualifying teams from third_place_info (already sorted by performance)
    qualifying_teams =
      third_place_info.qualifying
      |> Enum.map(fn entry ->
        get_team_at(standings_teams, entry.group, 2)
      end)

    Enum.zip(slots, qualifying_teams)
    |> Map.new()
  end

  defp build_third_lookup(_standings_teams, _qualifying_groups, _seeding, _third_place_info) do
    %{}
  end

  defp resolve_seed({:winner, group}, standings_teams, _third_lookup) do
    get_team_at(standings_teams, group, 0)
  end

  defp resolve_seed({:runner_up, group}, standings_teams, _third_lookup) do
    get_team_at(standings_teams, group, 1)
  end

  defp resolve_seed({:third, slot}, _standings_teams, third_lookup) do
    Map.get(third_lookup, slot)
  end

  defp get_team_at(standings_teams, group, index) do
    case Map.get(standings_teams, group) do
      teams when is_list(teams) -> Enum.at(teams, index)
      _ -> nil
    end
  end

  defp build_rounds(
         r32_matchups,
         predictions_by_round,
         overrides_by_round,
         all_tournament_teams,
         playoff_bracket_version
       ) do
    Enum.map(@rounds, fn round ->
      positions = BracketPrediction.positions_for_round(round)
      round_predictions = Map.get(predictions_by_round, round, [])
      round_overrides = Map.get(overrides_by_round, round, [])

      # Collect all teams already placed in this round
      placed_team_ids =
        round_predictions
        |> Enum.filter(& &1.team_id)
        |> Enum.map(& &1.team_id)
        |> MapSet.new()

      # Get the pool of teams available for swapping into this round
      swap_pool = get_swap_pool(round, r32_matchups, predictions_by_round, all_tournament_teams)

      matchup_context = %{
        round: round,
        r32_matchups: r32_matchups,
        predictions_by_round: predictions_by_round,
        round_overrides: round_overrides,
        playoff_bracket_version: playoff_bracket_version
      }

      all_displayed_team_ids =
        displayed_team_ids(positions, matchup_context)
        |> MapSet.union(placed_team_ids)

      slot_context =
        Map.merge(matchup_context, %{
          round_predictions: round_predictions,
          swap_pool: swap_pool,
          all_displayed_team_ids: all_displayed_team_ids
        })

      slots =
        Enum.map(1..positions, fn pos ->
          build_slot(pos, slot_context)
        end)

      %{
        round: round,
        display_name: BracketPrediction.round_display_name(round),
        slots: slots,
        slot_count: positions
      }
    end)
  end

  defp displayed_team_ids(positions, context) do
    Enum.reduce(1..positions, MapSet.new(), fn pos, acc ->
      {team_a, team_b} =
        get_matchup_teams(
          context.round,
          pos,
          context.r32_matchups,
          context.predictions_by_round,
          context.round_overrides,
          context.playoff_bracket_version
        )

      acc
      |> put_team_id(team_a)
      |> put_team_id(team_b)
    end)
  end

  defp put_team_id(team_ids, nil), do: team_ids
  defp put_team_id(team_ids, team), do: MapSet.put(team_ids, team.id)

  defp build_slot(pos, context) do
    prediction = Enum.find(context.round_predictions, &(&1.position == pos))

    {team_a, team_b} =
      get_matchup_teams(
        context.round,
        pos,
        context.r32_matchups,
        context.predictions_by_round,
        context.round_overrides,
        context.playoff_bracket_version
      )

    %{
      position: pos,
      predicted_team: prediction && prediction.team,
      team_a: team_a,
      team_b: team_b,
      swap_candidates: swap_candidates(context.swap_pool, context.all_displayed_team_ids)
    }
  end

  defp swap_candidates(swap_pool, all_displayed_team_ids) do
    Enum.reject(swap_pool, fn team ->
      MapSet.member?(all_displayed_team_ids, team.id)
    end)
  end

  # For R32: all tournament teams are potential swap candidates
  defp get_swap_pool("round_of_32", _r32_matchups, _predictions_by_round, all_tournament_teams) do
    all_tournament_teams
  end

  # For later rounds: teams that won their previous round match
  defp get_swap_pool(round, _r32_matchups, predictions_by_round, _all_tournament_teams) do
    case prev_round(round) do
      nil ->
        []

      prev ->
        predictions_by_round
        |> Map.get(prev, [])
        |> Enum.filter(& &1.team)
        |> Enum.map(& &1.team)
    end
  end

  defp get_matchup_teams(
         "round_of_32",
         pos,
         r32_matchups,
         _predictions_by_round,
         overrides,
         _playoff_bracket_version
       ) do
    {base_a, base_b} =
      case Enum.find(r32_matchups, &(&1.position == pos)) do
        %{home: home, away: away} -> {home, away}
        nil -> {nil, nil}
      end

    # Apply overrides if they exist
    team_a = find_override_team(overrides, pos, "a") || base_a
    team_b = find_override_team(overrides, pos, "b") || base_b

    {team_a, team_b}
  end

  defp get_matchup_teams(
         round,
         pos,
         _r32_matchups,
         predictions_by_round,
         overrides,
         playoff_bracket_version
       ) do
    # For later rounds, the two candidates are winners of the official feeder positions.
    {base_a, base_b} =
      case BracketSeeding.feeder_positions(round, pos, playoff_bracket_version) do
        {source_round_1, source_pos_1, source_round_2, source_pos_2} ->
          {
            prediction_team(predictions_by_round, source_round_1, source_pos_1),
            prediction_team(predictions_by_round, source_round_2, source_pos_2)
          }

        nil ->
          {nil, nil}
      end

    # Apply overrides if they exist
    team_a = find_override_team(overrides, pos, "a") || base_a
    team_b = find_override_team(overrides, pos, "b") || base_b

    {team_a, team_b}
  end

  defp find_override_team(overrides, position, side) do
    case Enum.find(overrides, &(&1.position == position && &1.side == side)) do
      %{team: team} when not is_nil(team) -> team
      _ -> nil
    end
  end

  defp prediction_team(predictions_by_round, round, position) do
    predictions_by_round
    |> Map.get(round, [])
    |> Enum.find(&(&1.position == position))
    |> case do
      %{team: team} -> team
      _ -> nil
    end
  end

  defp prev_round("round_of_16"), do: "round_of_32"
  defp prev_round("quarter_final"), do: "round_of_16"
  defp prev_round("semi_final"), do: "quarter_final"
  defp prev_round("final"), do: "semi_final"
  defp prev_round(_), do: nil

  # Sync bracket predictions to playoff_predictions for backward compat
  defp sync_to_playoff_prediction(user_id, team_id, round, include) do
    phase = round_to_phase(round)

    if include do
      Football.add_playoff_prediction(%{
        user_id: user_id,
        team_id: team_id,
        phase: phase
      })
    else
      Football.remove_playoff_prediction(%{
        user_id: user_id,
        team_id: team_id,
        phase: phase
      })
    end
  end

  # Short labels for stage indicator dots
  def stage_short_label("round_of_32"), do: "32"
  def stage_short_label("round_of_16"), do: "16"
  def stage_short_label("quarter_final"), do: "VF"
  def stage_short_label("semi_final"), do: "PF"
  def stage_short_label("final"), do: "F"
  def stage_short_label(_), do: "?"

  defp round_to_phase("round_of_32"), do: 32
  defp round_to_phase("round_of_16"), do: 16
  defp round_to_phase("quarter_final"), do: 8
  defp round_to_phase("semi_final"), do: 4
  defp round_to_phase("final"), do: 2
  defp round_to_phase(_), do: nil
end

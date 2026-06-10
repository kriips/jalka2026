defmodule Jalka2026Web.UserPredictionLive.Groups do
  use Jalka2026Web, :live_view

  alias Jalka2026.Football
  alias Jalka2026.Football.GroupScenarios
  alias Jalka2026.Football.Match
  alias Jalka2026.Football.MatchSimulation, as: Simulator
  alias Jalka2026.PredictionSync
  alias Jalka2026Web.Resolvers.FootballResolver
  alias Jalka2026Web.TelemetryHooks

  @groups Jalka2026.Football.groups()

  @impl true
  def mount(params, _session, socket) do
    TelemetryHooks.with_mount_telemetry(__MODULE__, socket, fn ->
      group = Map.get(params, "group")

      # Subscribe to prediction sync for multi-device updates
      if connected?(socket) do
        PredictionSync.subscribe(socket.assigns.current_user.id)
      end

      predictions =
        FootballResolver.list_matches_by_group(group)
        |> Enum.map(fn match -> add_score(match, socket) end)

      # Load historical matchup data for each match
      historical_data = load_historical_data(predictions)

      # Calculate predicted standings from user predictions
      predicted_standings = GroupScenarios.calculate_predicted_standings(predictions)

      # Build stream items with match ID as the DOM id
      prediction_items =
        Enum.map(predictions, fn {match, scores} ->
          %{id: "match-#{match.id}", match: match, scores: scores}
        end)

      {:ok,
       socket
       |> assign(
         group: group,
         predictions: predictions,
         predictions_done: predictions_done_count(predictions),
         focused_match_index: 0,
         focused_side: "home",
         prev_group: get_prev_group(group),
         next_group: get_next_group(group),
         historical_data: historical_data,
         # State for match analysis dropdown
         expanded_match_id: nil,
         simulation_data: nil,
         detailed_history: nil,
         simulating: false,
         # Predicted standings from user predictions
         predicted_standings: predicted_standings,
         prediction_deadline: Application.get_env(:jalka2026, :prediction_deadline),
         predictions_open: Jalka2026Web.LiveHelpers.predictions_open?()
       )
       |> stream(:prediction_items, prediction_items)}
    end)
  end

  defp get_prev_group(group) do
    case Enum.find_index(@groups, &(&1 == group)) do
      nil -> nil
      0 -> nil
      index -> Enum.at(@groups, index - 1)
    end
  end

  defp get_next_group(group) do
    case Enum.find_index(@groups, &(&1 == group)) do
      nil -> nil
      index when index == length(@groups) - 1 -> nil
      index -> Enum.at(@groups, index + 1)
    end
  end

  @impl true
  def handle_event("predictions_locked", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "Ennustamine on suletud - turniir on alanud")
     |> redirect(to: "/")}
  end

  @impl true
  def handle_event("keydown", %{"key" => key} = params, socket) do
    match_id = params["match-id"]
    side = params["side"]
    home_score = params["home-score"]
    away_score = params["away-score"]

    case key do
      "ArrowUp" ->
        handle_event(
          "inc-score",
          %{
            "match" => match_id,
            "side" => side,
            "home-score" => home_score,
            "away-score" => away_score
          },
          socket
        )

      "ArrowDown" ->
        handle_event(
          "dec-score",
          %{
            "match" => match_id,
            "side" => side,
            "home-score" => home_score,
            "away-score" => away_score
          },
          socket
        )

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("inc-score", user_params, socket) do
    changed_score = compute_changed_score(user_params, &inc_score/1)
    apply_score_change(changed_score, user_params, socket)
  end

  def handle_event("dec-score", user_params, socket) do
    changed_score = compute_changed_score(user_params, &dec_score/1)
    apply_score_change(changed_score, user_params, socket)
  end

  def handle_event(
        "set-score",
        %{"match" => match_id, "side" => side, "score" => score} = params,
        socket
      ) do
    score_val = if is_binary(score), do: String.to_integer(score), else: score
    score_val = max(0, min(score_val, 99))

    other_score =
      case side do
        "home" -> nullify_hyphen(params["away-score"] || "-")
        "away" -> nullify_hyphen(params["home-score"] || "-")
      end

    changed_score =
      case side do
        "home" -> {score_val, other_score}
        "away" -> {other_score, score_val}
      end

    apply_score_change(changed_score, %{"match" => match_id, "side" => side}, socket)
  end

  # Event handlers for match analysis dropdown
  def handle_event("toggle_analysis", %{"match-id" => match_id_str}, socket) do
    match_id = String.to_integer(match_id_str)

    if socket.assigns.expanded_match_id == match_id do
      {:noreply, close_analysis_panel(socket, match_id)}
    else
      {:noreply, open_analysis_panel(socket, match_id)}
    end
  end

  def handle_event("close_analysis", _params, socket) do
    # Re-insert the previously expanded match to remove the panel
    socket =
      if socket.assigns.expanded_match_id do
        prev_id = socket.assigns.expanded_match_id

        {prev_match, prev_scores} =
          Enum.find(socket.assigns.predictions, fn {m, _} -> m.id == prev_id end)

        stream_insert(socket, :prediction_items, %{
          id: "match-#{prev_match.id}",
          match: prev_match,
          scores: prev_scores
        })
      else
        socket
      end

    {:noreply,
     assign(socket,
       expanded_match_id: nil,
       simulation_data: nil,
       detailed_history: nil,
       simulating: false
     )}
  end

  # Simulate a random score and apply it to the prediction
  def handle_event("simulate_random_score", %{"match-id" => match_id_str}, socket) do
    if Jalka2026Web.LiveHelpers.predictions_open?() do
      match_id = String.to_integer(match_id_str)
      {match, _} = Enum.find(socket.assigns.predictions, fn {m, _} -> m.id == match_id end)

      # If simulation data is already loaded, use it; otherwise run a quick simulation
      {home_score, away_score} =
        if socket.assigns.simulation_data && socket.assigns.expanded_match_id == match_id do
          pick_weighted_random_score(socket.assigns.simulation_data.results.score_distribution)
        else
          # Run a single simulation to get a random score
          results =
            Simulator.simulate_match(match.home_team.code, match.away_team.code, simulations: 1)

          # Get the single result from score_distribution
          [{score, _count}] = Map.to_list(results.score_distribution)
          score
        end

      # Save the prediction
      updated_prediction =
        FootballResolver.change_prediction_score(%{
          match_id: match_id,
          user_id: socket.assigns.current_user.id,
          side: "home",
          score: {home_score, away_score}
        })

      # Broadcast to other devices
      PredictionSync.broadcast_group_prediction(
        socket.assigns.current_user.id,
        match_id,
        updated_prediction.home_score,
        updated_prediction.away_score,
        self()
      )

      {:noreply, socket |> update_prediction(match_id, updated_prediction)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Ennustamine on suletud - turniir on alanud")
       |> redirect(to: "/")}
    end
  end

  defp close_analysis_panel(socket, match_id) do
    {match, scores} = find_prediction(socket, match_id)

    socket
    |> assign(
      expanded_match_id: nil,
      simulation_data: nil,
      detailed_history: nil,
      simulating: false
    )
    |> stream_insert(:prediction_items, %{id: "match-#{match.id}", match: match, scores: scores})
  end

  defp open_analysis_panel(socket, match_id) do
    {match, scores} = find_prediction(socket, match_id)
    send(self(), {:load_analysis_data, match.home_team.code, match.away_team.code})

    socket
    |> close_previous_analysis_panel()
    |> assign(
      expanded_match_id: match_id,
      simulation_data: nil,
      detailed_history: nil,
      simulating: true
    )
    |> stream_insert(:prediction_items, %{id: "match-#{match.id}", match: match, scores: scores})
  end

  defp close_previous_analysis_panel(%{assigns: %{expanded_match_id: nil}} = socket), do: socket

  defp close_previous_analysis_panel(socket) do
    {prev_match, prev_scores} = find_prediction(socket, socket.assigns.expanded_match_id)

    stream_insert(socket, :prediction_items, %{
      id: "match-#{prev_match.id}",
      match: prev_match,
      scores: prev_scores
    })
  end

  defp find_prediction(socket, match_id) do
    Enum.find(socket.assigns.predictions, fn {match, _scores} -> match.id == match_id end)
  end

  # Toggle predicted standings visibility (always visible, kept for potential future use)

  # Pick a weighted random score from the score distribution
  defp pick_weighted_random_score(score_distribution) do
    total = score_distribution |> Map.values() |> Enum.sum()
    random_value = :rand.uniform(total)

    score_distribution
    |> Enum.reduce_while({0, nil}, fn {score, count}, {acc, _} ->
      new_acc = acc + count

      if new_acc >= random_value do
        {:halt, {new_acc, score}}
      else
        {:cont, {new_acc, nil}}
      end
    end)
    |> elem(1)
  end

  defp compute_changed_score(%{"side" => "home"} = params, score_fn) do
    {score_fn.(params["home-score"]), nullify_hyphen(params["away-score"])}
  end

  defp compute_changed_score(%{"side" => "away"} = params, score_fn) do
    {nullify_hyphen(params["home-score"]), score_fn.(params["away-score"])}
  end

  defp apply_score_change(changed_score, user_params, socket) do
    if Jalka2026Web.LiveHelpers.predictions_open?() do
      apply_score_if_allowed(changed_score, user_params, socket)
    else
      {:noreply,
       socket
       |> put_flash(:error, "Ennustamine on suletud - turniir on alanud")
       |> redirect(to: "/")}
    end
  end

  defp apply_score_if_allowed(changed_score, user_params, socket) do
    case Jalka2026Web.LiveRateLimiter.check_prediction_rate(socket.assigns.current_user.id) do
      :ok ->
        match_id = String.to_integer(user_params["match"])

        updated_prediction =
          FootballResolver.change_prediction_score(%{
            match_id: match_id,
            user_id: socket.assigns.current_user.id,
            side: user_params["side"],
            score: changed_score
          })

        # Broadcast to other devices
        {home_score, away_score} = {updated_prediction.home_score, updated_prediction.away_score}

        PredictionSync.broadcast_group_prediction(
          socket.assigns.current_user.id,
          match_id,
          home_score,
          away_score,
          self()
        )

        {:noreply, socket |> update_prediction(match_id, updated_prediction)}

      {:error, :rate_limited} ->
        {:noreply, socket |> put_flash(:error, "Liiga palju muudatusi. Oota veidi.")}
    end
  end

  defp add_score(%Match{} = match, socket) do
    scores =
      case FootballResolver.get_prediction(%{
             match_id: match.id,
             user_id: socket.assigns.current_user.id
           }) do
        %{home_score: home_score, away_score: away_score} -> {home_score, away_score}
        _ -> {"-", "-"}
      end

    {match, scores}
  end

  defp inc_score(score) do
    case score do
      "-" -> 1
      x -> String.to_integer(x) + 1
    end
  end

  defp dec_score(score) do
    case score do
      "-" -> 0
      "0" -> 0
      x -> String.to_integer(x) - 1
    end
  end

  defp nullify_hyphen(score) do
    case score do
      "-" -> 0
      x -> String.to_integer(x)
    end
  end

  defp update_prediction(socket, match_id, updated_prediction) do
    predictions =
      socket.assigns.predictions
      |> Enum.map(fn {match, _score} = prediction ->
        if match.id == match_id do
          {match, {updated_prediction.home_score, updated_prediction.away_score}}
        else
          prediction
        end
      end)

    # Recalculate predicted standings based on updated predictions
    predicted_standings = GroupScenarios.calculate_predicted_standings(predictions)

    # Find the updated match and stream_insert only that item
    {match, new_scores} = Enum.find(predictions, fn {m, _} -> m.id == match_id end)

    socket
    |> assign(
      predictions: predictions,
      predictions_done: predictions_done_count(predictions),
      predicted_standings: predicted_standings
    )
    |> stream_insert(:prediction_items, %{
      id: "match-#{match.id}",
      match: match,
      scores: new_scores
    })
  end

  defp predictions_done_count(predictions) do
    case Enum.count(predictions, fn {_pred, {home_score, away_score}} ->
           away_score != "-" or home_score != "-"
         end) < 6 do
      true -> "button-outline"
      _ -> ""
    end
  end

  defp load_historical_data(predictions) do
    predictions
    |> Enum.map(fn {match, _scores} ->
      home_code = match.home_team.code
      away_code = match.away_team.code

      stats = Football.get_historical_stats(home_code, away_code)
      world_cup_matches = Football.get_world_cup_matchup(home_code, away_code)

      {match.id,
       %{
         stats: stats,
         world_cup_matches: world_cup_matches
       }}
    end)
    |> Map.new()
  end

  def format_date(date) do
    Calendar.strftime(date, "%d.%m.%Y")
  end

  # Handle prediction sync from other devices
  @impl true
  def handle_info(
        {:prediction_sync, :group_prediction_changed, %{source_pid: source_pid} = data},
        socket
      )
      when source_pid != self() do
    # Update the local state with the change from another device
    match_id = data.match_id
    home_score = data.home_score
    away_score = data.away_score

    # Check if this match is in our current view
    match_in_view =
      Enum.any?(socket.assigns.predictions, fn {match, _} -> match.id == match_id end)

    if match_in_view do
      # Create a pseudo-prediction struct to update the UI
      updated_prediction = %{home_score: home_score, away_score: away_score}
      {:noreply, socket |> update_prediction(match_id, updated_prediction)}
    else
      {:noreply, socket}
    end
  end

  # Ignore sync messages from self
  def handle_info(
        {:prediction_sync, :group_prediction_changed, %{source_pid: source_pid}},
        socket
      )
      when source_pid == self() do
    {:noreply, socket}
  end

  # Ignore playoff sync messages in Groups view (they're handled in Playoffs view)
  def handle_info({:prediction_sync, :playoff_prediction_changed, _data}, socket) do
    {:noreply, socket}
  end

  # Handle async data loading - load all analysis data together
  @impl true
  def handle_info({:load_analysis_data, team1_code, team2_code}, socket) do
    # Load simulation data
    results = Simulator.simulate_match(team1_code, team2_code, simulations: 10_000)
    team1_breakdown = Simulator.get_strength_breakdown(team1_code, team2_code)
    team2_breakdown = Simulator.get_strength_breakdown(team2_code, team1_code)

    # Load history data
    matches = Football.get_historical_matchup(team1_code, team2_code)
    world_cup_matches = Football.get_world_cup_matchup(team1_code, team2_code)
    stats = Football.get_historical_stats(team1_code, team2_code)
    team1_form = Football.get_team_recent_form(team1_code, 5)
    team2_form = Football.get_team_recent_form(team2_code, 5)
    team1_wc_stats = Football.get_team_world_cup_stats(team1_code)
    team2_wc_stats = Football.get_team_world_cup_stats(team2_code)
    team1_wc_by_tournament = Football.get_team_world_cup_stats_by_tournament(team1_code)
    team2_wc_by_tournament = Football.get_team_world_cup_stats_by_tournament(team2_code)
    team1_wc_positions = Football.get_team_world_cup_positions(team1_code)
    team2_wc_positions = Football.get_team_world_cup_positions(team2_code)
    team1_wc_eliminations = Football.get_team_world_cup_eliminations(team1_code)
    team2_wc_eliminations = Football.get_team_world_cup_eliminations(team2_code)

    # Re-insert the stream item so the analysis panel re-renders with loaded data
    socket =
      socket
      |> assign(
        simulation_data: %{
          results: results,
          team1_breakdown: team1_breakdown,
          team2_breakdown: team2_breakdown
        },
        detailed_history: %{
          matches: matches,
          world_cup_matches: world_cup_matches,
          stats: stats,
          team1_form: team1_form,
          team2_form: team2_form,
          team1_wc_stats: team1_wc_stats,
          team2_wc_stats: team2_wc_stats,
          team1_wc_by_tournament: team1_wc_by_tournament,
          team2_wc_by_tournament: team2_wc_by_tournament,
          team1_wc_positions: team1_wc_positions,
          team2_wc_positions: team2_wc_positions,
          team1_wc_eliminations: team1_wc_eliminations,
          team2_wc_eliminations: team2_wc_eliminations
        },
        simulating: false
      )

    socket =
      if socket.assigns.expanded_match_id do
        match_id = socket.assigns.expanded_match_id
        {match, scores} = Enum.find(socket.assigns.predictions, fn {m, _} -> m.id == match_id end)

        stream_insert(socket, :prediction_items, %{
          id: "match-#{match.id}",
          match: match,
          scores: scores
        })
      else
        socket
      end

    {:noreply, socket}
  end

  # Helper functions for templates
  def probability_color(percentage) do
    cond do
      percentage >= 10.0 -> "probability-high"
      percentage >= 5.0 -> "probability-medium"
      percentage >= 2.0 -> "probability-low"
      percentage > 0 -> "probability-minimal"
      true -> "probability-zero"
    end
  end

  def strength_color(value) do
    cond do
      value >= 1.2 -> "strength-high"
      value >= 1.0 -> "strength-medium"
      value >= 0.8 -> "strength-low"
      true -> "strength-very-low"
    end
  end

  def format_percentage(value) do
    :erlang.float_to_binary(value, decimals: 1)
  end

  def home_away_indicator(true), do: "(K)"
  def home_away_indicator(false), do: "(V)"

  # Scenario helpers
  def status_class(:qualified), do: "status-qualified"
  def status_class(:eliminated), do: "status-eliminated"
  def status_class(:likely), do: "status-likely"
  def status_class(:possible), do: "status-possible"
  def status_class(:unlikely), do: "status-unlikely"
  def status_class(_), do: ""

  def status_label(:qualified), do: "Kindlalt edasi"
  def status_label(:eliminated), do: "Langenud"
  def status_label(:likely), do: "Tõenäoline"
  def status_label(:possible), do: "Võimalik"
  def status_label(:unlikely), do: "Ebatõenäoline"
  def status_label(_), do: "Teadmata"

  def format_goal_diff(gd) when gd > 0, do: "+#{gd}"
  def format_goal_diff(gd), do: "#{gd}"

  # Get position medal/icon for a specific year from positions data
  def get_position_for_year(positions_data, year) do
    case Enum.find(positions_data.finishes, fn f -> f.year == year end) do
      nil -> nil
      finish -> finish.position
    end
  end

  def position_icon(1), do: "🥇"
  def position_icon(2), do: "🥈"
  def position_icon(3), do: "🥉"
  def position_icon(4), do: "4."
  def position_icon(_), do: nil

  # Get elimination stage for a specific year from eliminations data
  def get_elimination_for_year(eliminations_data, year) do
    Map.get(eliminations_data, year)
  end

  # Get stage short name for display
  def stage_short(stage) do
    Football.stage_short_name(stage)
  end
end

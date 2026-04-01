defmodule Jalka2026Web.UserPredictionLive.Playoffs do
  use Jalka2026Web, :live_view

  alias Jalka2026Web.Resolvers.FootballResolver
  alias Jalka2026.Football.GroupScenarios
  alias Jalka2026.PredictionSync
  alias Jalka2026Web.TelemetryHooks

  @impl true
  def mount(_params, _session, socket) do
    TelemetryHooks.with_mount_telemetry(__MODULE__, socket, fn ->
      # Subscribe to prediction sync for multi-device updates
      if connected?(socket) do
        PredictionSync.subscribe(socket.assigns.current_user.id)
      end

      socket = add_teams(socket)
      # Get predicted qualifiers from user's group predictions
      predicted_qualifiers = GroupScenarios.get_all_predicted_qualifiers(socket.assigns.current_user.id)
      {:ok, assign(socket, predicted_qualifiers: predicted_qualifiers)}
    end)
  end

  @impl true
  def handle_event("toggle-team", user_params, socket) do
    if Jalka2026Web.LiveHelpers.predictions_open?() do
      case Jalka2026Web.LiveRateLimiter.check_playoff_prediction_rate(socket.assigns.current_user.id) do
        :ok ->
          team_id = String.to_integer(user_params["team"])
          phase = String.to_integer(user_params["phase"])
          include = user_params["value"] == "on"

          FootballResolver.change_playoff_prediction(%{
            user_id: socket.assigns.current_user.id,
            team_id: team_id,
            phase: phase,
            include: include
          })

          # Broadcast to other devices
          PredictionSync.broadcast_playoff_prediction(
            socket.assigns.current_user.id,
            team_id,
            phase,
            include,
            self()
          )

          {:noreply, add_teams(socket)}

        {:error, :rate_limited} ->
          {:noreply,
           socket
           |> Phoenix.LiveView.put_flash(:error, "Liiga palju muudatusi. Oota veidi.")}
      end
    else
      {:noreply,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Ennustamine on suletud - turniir on alanud")
       |> Phoenix.LiveView.redirect(to: "/")}
    end
  end

  # Handle prediction sync from other devices
  @impl true
  def handle_info({:prediction_sync, :playoff_prediction_changed, %{source_pid: source_pid}}, socket)
      when source_pid != self() do
    # Reload teams to reflect changes from another device
    {:noreply, add_teams(socket)}
  end

  # Ignore sync messages from self
  def handle_info({:prediction_sync, :playoff_prediction_changed, %{source_pid: source_pid}}, socket)
      when source_pid == self() do
    {:noreply, socket}
  end

  # Ignore group sync messages in Playoffs view (they're handled in Groups view)
  def handle_info({:prediction_sync, :group_prediction_changed, _data}, socket) do
    {:noreply, socket}
  end

  defp add_predictions(teams_with_group, predictions, phase) do
    teams_with_group
    |> Enum.map(fn {group, teams} ->
      teams =
        Enum.map(teams, fn {id, name} ->
          if Enum.member?(predictions[phase], id) do
            {id, name, "checked"}
          else
            {id, name, ""}
          end
        end)

      {group, teams}
    end)
  end

  defp add_predictions_without_group(teams_without_group, predictions, phase) do
    teams_without_group
    |> Enum.map(fn {id, name} ->
      if Enum.member?(predictions[phase], id) do
        {id, name, "checked"}
      else
        {id, name, ""}
      end
    end)
  end

  defp get_teams_from_predictions(teams_with_group, predictions, phase) do
    teams_with_group
    |> Enum.reduce([], fn {_group, teams}, acc ->
      [teams | acc]
    end)
    |> List.flatten()
    |> Enum.reduce([], fn {id, name}, acc ->
      if Enum.member?(predictions[phase], id) do
        [{id, name} | acc]
      else
        acc
      end
    end)
  end

  defp count_left_with_group(teams_with_group) do
    teams_with_group
    |> Enum.map(fn {_group, teams} ->
      teams
    end)
    |> List.flatten()
    |> count_left
  end

  defp count_left(teams) do
    teams
    |> Enum.count(fn {_id, _name, checked} ->
      checked == "checked"
    end)
  end

  defp is_disabled(count_left) do
    if count_left == 0 do
      "disabled"
    else
      ""
    end
  end

  defp add_teams(socket) do
    predictions = FootballResolver.get_playoff_predictions(socket.assigns.current_user.id)
    teams = FootballResolver.get_teams_by_group()

    teams32 =
      teams
      |> add_predictions(predictions, 32)

    teams16 =
      teams
      |> get_teams_from_predictions(predictions, 32)
      |> add_predictions_without_group(predictions, 16)

    teams8 =
      teams
      |> get_teams_from_predictions(predictions, 16)
      |> add_predictions_without_group(predictions, 8)

    teams4 =
      teams
      |> get_teams_from_predictions(predictions, 8)
      |> add_predictions_without_group(predictions, 4)

    teams2 =
      teams
      |> get_teams_from_predictions(predictions, 4)
      |> add_predictions_without_group(predictions, 2)

    teams1 =
      teams
      |> get_teams_from_predictions(predictions, 2)
      |> add_predictions_without_group(predictions, 1)

    left32 = 32 - count_left_with_group(teams32)
    left16 = 16 - count_left(teams16)
    left8 = 8 - count_left(teams8)
    left4 = 4 - count_left(teams4)
    left2 = 2 - count_left(teams2)
    left1 = 1 - count_left(teams1)

    progress = 63 - left32 - left16 - left8 - left4 - left2 - left1

    predictions_done =
      if progress != 63 do
        "button-outline"
      end

    if progress == 63 do
      Jalka2026.Leaderboard.recalc_leaderboard()
    end

    assign(socket,
      teams32: teams32,
      left32: left32,
      disabled32: is_disabled(left32),
      teams16: teams16,
      left16: left16,
      disabled16: is_disabled(left16),
      teams8: teams8,
      left8: left8,
      disabled8: is_disabled(left8),
      teams4: teams4,
      left4: left4,
      disabled4: is_disabled(left4),
      teams2: teams2,
      left2: left2,
      disabled2: is_disabled(left2),
      teams1: teams1,
      left1: left1,
      disabled1: is_disabled(left1),
      predictions_done: predictions_done
    )
  end
end

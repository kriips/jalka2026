defmodule Jalka2026Web.FootballLive.Game do
  use Jalka2026Web, :live_view

  alias Jalka2026Web.Resolvers.FootballResolver
  alias Jalka2026.Football.GroupScenarios
  alias Jalka2026.Chat
  alias Jalka2026Web.Live.Components.MatchChat

  @impl true
  def mount(params, session, socket) do
    socket = Phoenix.Component.assign_new(socket, :current_user, fn ->
      find_current_user(session)
    end)

    case FootballResolver.list_match(params["id"]) do
      nil ->
        {:ok, socket |> redirect(to: "/football/games")}

      match ->
        # Subscribe to chat updates for this match
        if connected?(socket) do
          Chat.subscribe(match.id)
        end

        # Extract group letter from match.group (e.g., "Alagrupp A" -> "A")
        group_letter = extract_group_letter(match.group)

        # Load group scenario data if this is a group stage match
        {scenario_data, team_requirements} =
          if group_letter do
            {
              GroupScenarios.calculate_scenarios(group_letter),
              GroupScenarios.analyze_team_requirements(group_letter)
            }
          else
            {nil, nil}
          end

        {:ok,
         socket
         |> assign(
           predictions: FootballResolver.get_predictions_by_match_result(params["id"]),
           crowd_confidence: FootballResolver.get_crowd_confidence(params["id"]),
           match: match,
           group_letter: group_letter,
           scenario_data: scenario_data,
           team_requirements: team_requirements,
           show_scenarios: group_letter != nil,
           selected_scenario: nil
         )}
    end
  end

  defp find_current_user(session) do
    with user_token when not is_nil(user_token) <- session["user_token"],
         %Jalka2026.Accounts.User{} = user <- Jalka2026.Accounts.get_user_by_session_token(user_token),
         do: user
  end

  @impl true
  def handle_event("select_scenario", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    scenarios = socket.assigns.scenario_data.scenarios

    selected =
      if index >= 0 and index < length(scenarios) do
        Enum.at(scenarios, index)
      else
        nil
      end

    {:noreply, assign(socket, selected_scenario: selected)}
  end

  def handle_event("clear_scenario", _params, socket) do
    {:noreply, assign(socket, selected_scenario: nil)}
  end

  @impl true
  def handle_info({:new_comment, _comment}, socket) do
    # Trigger a re-render of the chat component by sending an update
    send_update(MatchChat, id: "match-chat", match_id: socket.assigns.match.id, current_user: socket.assigns.current_user)
    {:noreply, push_event(socket, "new-comment", %{})}
  end

  def handle_info({:delete_comment, _comment_id}, socket) do
    # Trigger a re-render of the chat component
    send_update(MatchChat, id: "match-chat", match_id: socket.assigns.match.id, current_user: socket.assigns.current_user)
    {:noreply, socket}
  end

  defp extract_group_letter(nil), do: nil
  defp extract_group_letter(group) do
    case Regex.run(~r/Alagrupp ([A-L])/, group) do
      [_, letter] -> letter
      _ -> nil
    end
  end

  # Helper functions for template
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

  def outcome_label(:home_win), do: "1"
  def outcome_label(:draw), do: "X"
  def outcome_label(:away_win), do: "2"

  def format_goal_diff(gd) when gd > 0, do: "+#{gd}"
  def format_goal_diff(gd), do: "#{gd}"

  def rank_class(1), do: "gold"
  def rank_class(2), do: "silver"
  def rank_class(3), do: "bronze"
  def rank_class(_), do: "default"
end

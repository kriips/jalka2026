defmodule Jalka2026Web.FootballLive.Game do
  use Jalka2026Web, :live_view

  alias Jalka2026.Chat
  alias Jalka2026Web.Components.MatchHistory
  alias Jalka2026Web.Live.Components.MatchChat
  alias Jalka2026Web.Resolvers.FootballResolver

  @impl true
  def mount(params, _session, socket) do
    case FootballResolver.list_match(params["id"]) do
      nil ->
        {:ok, socket |> redirect(to: "/football/games")}

      match ->
        # Subscribe to chat updates for this match
        if connected?(socket) do
          Chat.subscribe(match.id)
        end

        {:ok,
         socket
         |> assign(
           predictions: FootballResolver.get_predictions_by_match_result(params["id"]),
           crowd_confidence: FootballResolver.get_crowd_confidence(params["id"]),
           match: match,
           analysis_expanded: false,
           detailed_history: nil,
           simulating: false
         )}
    end
  end

  @impl true
  def handle_event("toggle_analysis", _params, socket) do
    if socket.assigns.analysis_expanded do
      {:noreply,
       assign(socket, analysis_expanded: false, detailed_history: nil, simulating: false)}
    else
      match = socket.assigns.match
      send(self(), {:load_analysis_data, match.home_team.code, match.away_team.code})

      {:noreply,
       assign(socket, analysis_expanded: true, detailed_history: nil, simulating: true)}
    end
  end

  @impl true
  def handle_info({:load_analysis_data, team1_code, team2_code}, socket) do
    {:noreply,
     assign(socket,
       detailed_history: MatchHistory.load_history(team1_code, team2_code),
       simulating: false
     )}
  end

  def handle_info({:new_comment, _comment}, socket) do
    # Trigger a re-render of the chat component by sending an update
    send_update(MatchChat,
      id: "match-chat",
      match_id: socket.assigns.match.id,
      current_user: socket.assigns.current_user
    )

    {:noreply, push_event(socket, "new-comment", %{})}
  end

  def handle_info({:delete_comment, _comment_id}, socket) do
    # Trigger a re-render of the chat component
    send_update(MatchChat,
      id: "match-chat",
      match_id: socket.assigns.match.id,
      current_user: socket.assigns.current_user
    )

    {:noreply, socket}
  end
end

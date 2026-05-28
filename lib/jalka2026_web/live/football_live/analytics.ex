defmodule Jalka2026Web.FootballLive.Analytics do
  use Jalka2026Web, :live_view

  alias Jalka2026.Badges
  alias Jalka2026.Football
  alias Jalka2026.Leaderboard
  alias Jalka2026.Leaderboard.Entry
  alias Jalka2026Web.Resolvers.AccountsResolver
  alias Jalka2026Web.Resolvers.FootballResolver

  @impl true
  def mount(params, _session, socket) do
    user_id = params["id"]
    user_id_int = String.to_integer(user_id)

    user = AccountsResolver.get_user(user_id)
    analytics = FootballResolver.get_prediction_analytics(user_id)
    favorite_teams = Football.get_user_favorite_teams(user_id_int)
    user_badges = Badges.get_user_badges(user_id_int)

    # Get leaderboard position
    leaderboard = Leaderboard.get_leaderboard()
    leaderboard_entry = Enum.find(leaderboard, fn %Entry{user_id: id} -> id == user_id_int end)

    {:ok,
     socket
     |> assign(
       user: user,
       analytics: analytics,
       favorite_teams: favorite_teams,
       user_badges: user_badges,
       leaderboard_entry: leaderboard_entry,
       selected_tab: "overview"
     )}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, selected_tab: tab)}
  end
end

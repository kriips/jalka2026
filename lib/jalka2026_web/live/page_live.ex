defmodule Jalka2026Web.PageLive do
  use Jalka2026Web, :live_view

  alias Jalka2026Web.Resolvers.FootballResolver

  @impl true
  def mount(_params, _session, socket) do
    deadline = Application.get_env(:jalka2026, :prediction_deadline)
    predictions_open = Jalka2026Web.LiveHelpers.predictions_open?()

    socket =
      socket
      |> assign(
        query: "",
        results: %{},
        prediction_deadline: deadline,
        predictions_open: predictions_open
      )
      |> assign_onboarding()

    {:ok, socket}
  end

  @impl true
  def handle_event("predictions_locked", _params, socket) do
    {:noreply, assign(socket, predictions_open: false)}
  end

  @impl true
  def handle_event("leaderboard_visited", _params, socket) do
    {:noreply, assign(socket, leaderboard_visited: true)}
  end

  @impl true
  def handle_event("dismiss_onboarding", _params, socket) do
    {:noreply, assign(socket, show_onboarding: false)}
  end

  defp assign_onboarding(socket) do
    case {socket.assigns[:current_user], socket.assigns.predictions_open} do
      {nil, _} ->
        assign(socket, show_onboarding: false)

      {_user, false} ->
        assign(socket, show_onboarding: false)

      {user, true} ->
        filled = FootballResolver.filled_predictions(user.id)

        group_count =
          Enum.reduce(filled, 0, fn {_group, count}, acc -> acc + count end)

        bracket_predictions = Jalka2026.Football.get_bracket_predictions_by_user(user.id)

        playoff_count =
          Enum.count(bracket_predictions, fn bp -> bp.team_id != nil end)

        playoff_total = 16 + 8 + 4 + 2 + 1

        groups_complete = group_count == 72
        playoffs_complete = playoff_count == playoff_total

        assign(socket,
          show_onboarding: true,
          groups_complete: groups_complete,
          playoffs_complete: playoffs_complete,
          leaderboard_visited: false,
          group_count: group_count,
          playoff_count: playoff_count,
          playoff_total: playoff_total
        )
    end
  end
end

defmodule Jalka2026Web.AdminLive.Dashboard do
  use Jalka2026Web, :live_view

  alias Jalka2026.Competitions
  alias Jalka2026.Leaderboard
  alias Jalka2026Web.Resolvers.AccountsResolver
  alias Jalka2026Web.Resolvers.FootballResolver

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Refresh stats every 30 seconds
      :timer.send_interval(30_000, self(), :refresh_stats)
    end

    {:ok, assign_stats(socket)}
  end

  @impl true
  def handle_info(:refresh_stats, socket) do
    {:noreply, assign_stats(socket)}
  end

  @impl true
  def handle_event("recalc_leaderboard", _params, socket) do
    Leaderboard.recalc_leaderboard()

    {:noreply,
     socket
     |> put_flash(:info, "Edetabel uuendatud")
     |> assign_stats()}
  end

  defp assign_stats(socket) do
    users = AccountsResolver.list_users()
    matches = FootballResolver.list_matches()
    finished_matches = FootballResolver.list_finished_matches()

    # Calculate prediction stats
    total_predictions = count_total_predictions(users)
    expected_predictions = length(users) * length(matches)

    # System health checks
    leaderboard = Leaderboard.get_leaderboard()

    current_competition = Competitions.current()
    competitions = Competitions.list()

    socket
    |> assign(:user_count, length(users))
    |> assign(:match_count, length(matches))
    |> assign(:finished_match_count, length(finished_matches))
    |> assign(:total_predictions, total_predictions)
    |> assign(:expected_predictions, expected_predictions)
    |> assign(
      :prediction_completion,
      calculate_completion(total_predictions, expected_predictions)
    )
    |> assign(:leaderboard_size, length(leaderboard))
    |> assign(:predictions_open, Jalka2026Web.LiveHelpers.predictions_open?())
    |> assign(:current_competition, current_competition)
    |> assign(:competitions, competitions)
  end

  defp count_total_predictions(users) do
    users
    |> Enum.map(fn user ->
      FootballResolver.filled_predictions(user.id)
      |> Map.values()
      |> Enum.sum()
    end)
    |> Enum.sum()
  end

  defp calculate_completion(total, expected) when expected > 0 do
    Float.round(total / expected * 100, 1)
  end

  defp calculate_completion(_, _), do: 0.0
end

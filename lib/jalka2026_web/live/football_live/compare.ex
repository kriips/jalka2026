defmodule Jalka2026Web.FootballLive.Compare do
  use Jalka2026Web, :live_view

  alias Jalka2026.Leaderboard
  alias Jalka2026Web.Resolvers.AccountsResolver
  alias Jalka2026Web.Resolvers.FootballResolver

  # Helper functions for template
  def get_prediction_class(true, _correct_result), do: "correct-score"
  def get_prediction_class(false, true), do: "correct-result"
  def get_prediction_class(false, false), do: "wrong"

  def comparison_class(val1, val2) do
    cond do
      val1 > val2 -> "winning"
      val1 < val2 -> "losing"
      true -> "tied"
    end
  end

  @impl true
  def mount(params, _session, socket) do
    user1_id = params["user1"]
    user2_id = params["user2"]
    leaderboard = Leaderboard.get_leaderboard()
    users = get_users_for_dropdown(leaderboard)

    socket =
      socket
      |> assign(
        users: users,
        user1_id: user1_id,
        user2_id: user2_id,
        user1: nil,
        user2: nil,
        comparison: nil,
        view_mode: "summary"
      )

    socket =
      if user1_id && user2_id do
        load_comparison(socket, user1_id, user2_id)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    user1_id = params["user1"]
    user2_id = params["user2"]

    # Check if IDs changed BEFORE updating assigns
    ids_changed = user1_id != socket.assigns.user1_id || user2_id != socket.assigns.user2_id

    socket =
      socket
      |> assign(user1_id: user1_id, user2_id: user2_id)

    socket =
      if user1_id && user2_id && ids_changed do
        load_comparison(socket, user1_id, user2_id)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_users", %{"user1" => user1_id, "user2" => user2_id}, socket) do
    if user1_id != "" && user2_id != "" && user1_id != user2_id do
      {:noreply,
       push_patch(socket,
         to: Routes.football_compare_path(socket, :view, user1: user1_id, user2: user2_id)
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_view", %{"view" => view_mode}, socket) do
    {:noreply, assign(socket, view_mode: view_mode)}
  end

  defp load_comparison(socket, user1_id, user2_id) do
    user1 = AccountsResolver.get_user(user1_id)
    user2 = AccountsResolver.get_user(user2_id)
    comparison = FootballResolver.compare_predictions(user1_id, user2_id)

    socket
    |> assign(
      user1: user1,
      user2: user2,
      comparison: comparison
    )
  end

  defp get_users_for_dropdown(leaderboard) do
    leaderboard
    |> Enum.map(fn %{user_id: id, name: name} ->
      {id, name}
    end)
    |> Enum.sort_by(fn {_id, name} -> String.downcase(name) end)
  end
end

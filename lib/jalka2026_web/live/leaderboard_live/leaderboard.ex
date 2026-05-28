defmodule Jalka2026Web.LeaderboardLive.Leaderboard do
  use Jalka2026Web, :live_view

  alias Jalka2026.Badges
  alias Jalka2026.Football
  alias Jalka2026.Leaderboard
  alias Jalka2026.Leaderboard.Entry
  alias Jalka2026Web.TelemetryHooks

  @sort_options [
    {"total", "Kokku punktid"},
    {"group", "Grupi punktid"},
    {"playoff", "Playoffi punktid"},
    {"bonus", "Boonuspunktid"},
    {"streak", "Praegune seeria"},
    {"name", "Nimi"}
  ]

  @points_filter_options [
    {"all", "Kõik punktid"},
    {"group", "Ainult grupi punktid"},
    {"playoff", "Ainult playoffi punktid"}
  ]

  @impl true
  def mount(params, _session, socket) do
    TelemetryHooks.with_mount_telemetry(__MODULE__, socket, fn ->
      if connected?(socket), do: Leaderboard.subscribe()

      sort_by = Map.get(params, "sort_by", "total")
      points_filter = Map.get(params, "points_filter", "all")

      raw_leaderboard = Leaderboard.get_leaderboard()
      user_ids = Enum.map(raw_leaderboard, fn %Entry{user_id: id} -> id end)
      user_favorite_teams = Football.get_favorite_teams_for_users(user_ids)
      user_badges = Badges.get_badges_for_users(user_ids)

      # Get rivalry leaderboard for current user if logged in
      current_user = Map.get(socket.assigns, :current_user)

      rivalry_leaderboard =
        case current_user do
          nil -> []
          user -> build_rivalry_leaderboard(user.id, raw_leaderboard)
        end

      leaderboard = apply_filters_and_sort(raw_leaderboard, sort_by, points_filter)

      {:ok,
       socket
       |> assign(
         raw_leaderboard: raw_leaderboard,
         leaderboard: leaderboard,
         user_favorite_teams: user_favorite_teams,
         user_badges: user_badges,
         rivalry_leaderboard: rivalry_leaderboard,
         has_current_user: current_user != nil,
         changes: %{},
         flash_updates: false,
         sort_by: sort_by,
         points_filter: points_filter,
         sort_options: @sort_options,
         points_filter_options: @points_filter_options
       )
       |> stream(
         :leaderboard_rows,
         leaderboard_to_stream_items(leaderboard, %{}, false, user_favorite_teams, user_badges)
       )}
    end)
  end

  defp leaderboard_to_stream_items(
         leaderboard,
         changes,
         flash_updates,
         user_favorite_teams,
         user_badges
       ) do
    Enum.map(leaderboard, fn %Entry{} = entry ->
      change = Map.get(changes, entry.user_id, %{})

      %{
        id: "leaderboard-row-#{entry.user_id}",
        user_id: entry.user_id,
        rank: entry.rank,
        name: entry.name,
        gpoints: entry.group_points,
        ppoints: entry.playoff_points,
        bpoints: entry.bonus_points,
        current_streak: entry.current_streak,
        longest_streak: entry.longest_streak,
        points: entry.total_points,
        change: change,
        rank_change: Map.get(change, :rank_change, 0),
        points_change: Map.get(change, :points_change, 0),
        flash_updates: flash_updates,
        favorite_team: get_user_primary_team(user_favorite_teams, entry.user_id),
        badges: Map.get(user_badges, entry.user_id, [])
      }
    end)
  end

  @impl true
  def handle_params(params, _uri, socket) do
    sort_by = Map.get(params, "sort_by", socket.assigns.sort_by)
    points_filter = Map.get(params, "points_filter", socket.assigns.points_filter)
    leaderboard = apply_filters_and_sort(socket.assigns.raw_leaderboard, sort_by, points_filter)

    {:noreply,
     socket
     |> assign(
       sort_by: sort_by,
       points_filter: points_filter,
       leaderboard: leaderboard
     )
     |> stream(
       :leaderboard_rows,
       leaderboard_to_stream_items(
         leaderboard,
         socket.assigns.changes,
         socket.assigns.flash_updates,
         socket.assigns.user_favorite_teams,
         socket.assigns.user_badges
       ),
       reset: true
     )}
  end

  @impl true
  def handle_event("filter_change", params, socket) do
    sort_by = Map.get(params, "sort_by", socket.assigns.sort_by)
    points_filter = Map.get(params, "points_filter", socket.assigns.points_filter)

    {:noreply,
     push_patch(socket,
       to:
         Routes.leaderboard_leaderboard_path(socket, :view,
           sort_by: sort_by,
           points_filter: points_filter
         )
     )}
  end

  @impl true
  def handle_info({:leaderboard_updated, leaderboard, changes}, socket) do
    user_ids = Enum.map(leaderboard, fn %Entry{user_id: id} -> id end)
    user_favorite_teams = Football.get_favorite_teams_for_users(user_ids)
    user_badges = Badges.get_badges_for_users(user_ids)

    # Update rivalry leaderboard
    current_user = Map.get(socket.assigns, :current_user)

    rivalry_leaderboard =
      case current_user do
        nil -> []
        user -> build_rivalry_leaderboard(user.id, leaderboard)
      end

    sorted_leaderboard =
      apply_filters_and_sort(leaderboard, socket.assigns.sort_by, socket.assigns.points_filter)

    {:noreply,
     socket
     |> assign(
       raw_leaderboard: leaderboard,
       leaderboard: sorted_leaderboard,
       user_favorite_teams: user_favorite_teams,
       user_badges: user_badges,
       rivalry_leaderboard: rivalry_leaderboard,
       changes: changes,
       flash_updates: true
     )
     |> stream(
       :leaderboard_rows,
       leaderboard_to_stream_items(
         sorted_leaderboard,
         changes,
         true,
         user_favorite_teams,
         user_badges
       ),
       reset: true
     )
     |> push_event("leaderboard-updated", %{changes: changes})}
  end

  def get_user_primary_team(user_favorite_teams, user_id) do
    case Map.get(user_favorite_teams, user_id, []) do
      [primary | _] -> primary.team
      [] -> nil
    end
  end

  # Apply filtering and sorting to the leaderboard
  defp apply_filters_and_sort(leaderboard, sort_by, points_filter) do
    leaderboard
    |> apply_sort(sort_by)
    |> recalculate_display_points(points_filter)
  end

  defp apply_sort(leaderboard, "total") do
    Enum.sort_by(leaderboard, & &1.total_points, :desc)
  end

  defp apply_sort(leaderboard, "group") do
    Enum.sort_by(leaderboard, & &1.group_points, :desc)
  end

  defp apply_sort(leaderboard, "playoff") do
    Enum.sort_by(leaderboard, & &1.playoff_points, :desc)
  end

  defp apply_sort(leaderboard, "bonus") do
    Enum.sort_by(leaderboard, & &1.bonus_points, :desc)
  end

  defp apply_sort(leaderboard, "streak") do
    Enum.sort_by(leaderboard, & &1.current_streak, :desc)
  end

  defp apply_sort(leaderboard, "name") do
    Enum.sort_by(leaderboard, &String.downcase(&1.name), :asc)
  end

  defp apply_sort(leaderboard, _), do: leaderboard

  # Recalculate display ranks based on the filtered points
  defp recalculate_display_points(leaderboard, "group") do
    leaderboard
    |> Enum.sort_by(& &1.group_points, :desc)
    |> add_display_rank(& &1.group_points)
  end

  defp recalculate_display_points(leaderboard, "playoff") do
    leaderboard
    |> Enum.sort_by(& &1.playoff_points, :desc)
    |> add_display_rank(& &1.playoff_points)
  end

  defp recalculate_display_points(leaderboard, _) do
    # For "all", recalculate ranks based on total points after sort
    leaderboard
    |> Enum.sort_by(& &1.total_points, :desc)
    |> add_display_rank(& &1.total_points)
  end

  defp add_display_rank(sorted_leaderboard, points_fn) do
    sorted_leaderboard
    |> Enum.with_index(1)
    |> Enum.reduce({[], nil, 1}, fn {%Entry{} = entry, index}, {acc, prev_points, current_rank} ->
      points = points_fn.(entry)
      new_rank = if points == prev_points, do: current_rank, else: index
      {[%{entry | rank: new_rank} | acc], points, new_rank}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  # Helper function to get display points based on filter
  def display_points(%Entry{group_points: gp}, "group"), do: gp
  def display_points(%Entry{playoff_points: pp}, "playoff"), do: pp
  def display_points(%Entry{total_points: total}, _), do: total

  # Build rivalry leaderboard: shows current user and their rivals with stats
  defp build_rivalry_leaderboard(user_id, leaderboard) do
    rivalries = Football.get_user_rivalries(user_id)

    if rivalries == [] do
      []
    else
      leaderboard_map =
        Map.new(leaderboard, fn %Entry{} = entry ->
          {entry.user_id,
           %{
             id: entry.user_id,
             rank: entry.rank,
             name: entry.name,
             group_points: entry.group_points,
             playoff_points: entry.playoff_points,
             bonus_points: entry.bonus_points,
             current_streak: entry.current_streak,
             longest_streak: entry.longest_streak,
             total_points: entry.total_points
           }}
        end)

      # Get current user from leaderboard
      current_user_data = Map.get(leaderboard_map, user_id)

      # Get rivals from leaderboard
      rival_data =
        rivalries
        |> Enum.map(&build_rival_entry(&1, leaderboard_map, user_id))
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(fn r -> r.user.total_points end, :desc)

      %{
        current_user: current_user_data,
        rivals: rival_data
      }
    end
  end

  defp build_rival_entry(rivalry, leaderboard_map, user_id) do
    case Map.get(leaderboard_map, rivalry.rival_id) do
      nil ->
        nil

      rival ->
        stats = Football.get_rivalry_stats(user_id, rivalry.rival_id)
        %{user: rival, rivalry: rivalry, stats: stats}
    end
  end
end

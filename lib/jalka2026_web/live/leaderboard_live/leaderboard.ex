defmodule Jalka2026Web.LeaderboardLive.Leaderboard do
  use Jalka2026Web, :live_view

  alias Jalka2026.Leaderboard
  alias Jalka2026.Football
  alias Jalka2026.Badges
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
      user_ids = Enum.map(raw_leaderboard, fn {id, _, _, _, _, _, _, _, _} -> id end)
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
       |> stream(:leaderboard_rows, leaderboard_to_stream_items(leaderboard, %{}, false, user_favorite_teams, user_badges))}
    end)
  end

  defp leaderboard_to_stream_items(leaderboard, changes, flash_updates, user_favorite_teams, user_badges) do
    Enum.map(leaderboard, fn {id, rank, name, gpoints, ppoints, bpoints, current_streak, longest_streak, points} ->
      change = Map.get(changes, id, %{})
      %{
        id: "leaderboard-row-#{id}",
        user_id: id,
        rank: rank,
        name: name,
        gpoints: gpoints,
        ppoints: ppoints,
        bpoints: bpoints,
        current_streak: current_streak,
        longest_streak: longest_streak,
        points: points,
        change: change,
        rank_change: Map.get(change, :rank_change, 0),
        points_change: Map.get(change, :points_change, 0),
        flash_updates: flash_updates,
        favorite_team: get_user_primary_team(user_favorite_teams, id),
        badges: Map.get(user_badges, id, [])
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
     |> stream(:leaderboard_rows, leaderboard_to_stream_items(leaderboard, socket.assigns.changes, socket.assigns.flash_updates, socket.assigns.user_favorite_teams, socket.assigns.user_badges), reset: true)}
  end

  @impl true
  def handle_event("filter_change", params, socket) do
    sort_by = Map.get(params, "sort_by", socket.assigns.sort_by)
    points_filter = Map.get(params, "points_filter", socket.assigns.points_filter)

    {:noreply,
     push_patch(socket,
       to: Routes.leaderboard_leaderboard_path(socket, :view, sort_by: sort_by, points_filter: points_filter)
     )}
  end

  @impl true
  def handle_info({:leaderboard_updated, leaderboard, changes}, socket) do
    user_ids = Enum.map(leaderboard, fn {id, _, _, _, _, _, _, _, _} -> id end)
    user_favorite_teams = Football.get_favorite_teams_for_users(user_ids)
    user_badges = Badges.get_badges_for_users(user_ids)

    # Update rivalry leaderboard
    current_user = Map.get(socket.assigns, :current_user)
    rivalry_leaderboard =
      case current_user do
        nil -> []
        user -> build_rivalry_leaderboard(user.id, leaderboard)
      end

    sorted_leaderboard = apply_filters_and_sort(leaderboard, socket.assigns.sort_by, socket.assigns.points_filter)

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
     |> stream(:leaderboard_rows, leaderboard_to_stream_items(sorted_leaderboard, changes, true, user_favorite_teams, user_badges), reset: true)
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
    Enum.sort_by(leaderboard, fn {_id, _rank, _name, _gp, _pp, _bp, _cs, _ls, total} -> total end, :desc)
  end

  defp apply_sort(leaderboard, "group") do
    Enum.sort_by(leaderboard, fn {_id, _rank, _name, gp, _pp, _bp, _cs, _ls, _total} -> gp end, :desc)
  end

  defp apply_sort(leaderboard, "playoff") do
    Enum.sort_by(leaderboard, fn {_id, _rank, _name, _gp, pp, _bp, _cs, _ls, _total} -> pp end, :desc)
  end

  defp apply_sort(leaderboard, "bonus") do
    Enum.sort_by(leaderboard, fn {_id, _rank, _name, _gp, _pp, bp, _cs, _ls, _total} -> bp end, :desc)
  end

  defp apply_sort(leaderboard, "streak") do
    Enum.sort_by(leaderboard, fn {_id, _rank, _name, _gp, _pp, _bp, cs, _ls, _total} -> cs end, :desc)
  end

  defp apply_sort(leaderboard, "name") do
    Enum.sort_by(leaderboard, fn {_id, _rank, name, _gp, _pp, _bp, _cs, _ls, _total} -> String.downcase(name) end, :asc)
  end

  defp apply_sort(leaderboard, _), do: leaderboard

  # Recalculate display ranks based on the filtered points
  defp recalculate_display_points(leaderboard, "group") do
    leaderboard
    |> Enum.sort_by(fn {_id, _rank, _name, gp, _pp, _bp, _cs, _ls, _total} -> gp end, :desc)
    |> add_display_rank(fn {_id, _rank, _name, gp, _pp, _bp, _cs, _ls, _total} -> gp end)
  end

  defp recalculate_display_points(leaderboard, "playoff") do
    leaderboard
    |> Enum.sort_by(fn {_id, _rank, _name, _gp, pp, _bp, _cs, _ls, _total} -> pp end, :desc)
    |> add_display_rank(fn {_id, _rank, _name, _gp, pp, _bp, _cs, _ls, _total} -> pp end)
  end

  defp recalculate_display_points(leaderboard, _) do
    # For "all", recalculate ranks based on total points after sort
    leaderboard
    |> Enum.sort_by(fn {_id, _rank, _name, _gp, _pp, _bp, _cs, _ls, total} -> total end, :desc)
    |> add_display_rank(fn {_id, _rank, _name, _gp, _pp, _bp, _cs, _ls, total} -> total end)
  end

  defp add_display_rank(sorted_leaderboard, points_fn) do
    sorted_leaderboard
    |> Enum.with_index(1)
    |> Enum.reduce({[], nil, 1}, fn {{id, _old_rank, name, gp, pp, bp, cs, ls, total}, index}, {acc, prev_points, current_rank} ->
      points = points_fn.({id, nil, name, gp, pp, bp, cs, ls, total})
      new_rank = if points == prev_points, do: current_rank, else: index
      {[{id, new_rank, name, gp, pp, bp, cs, ls, total} | acc], points, new_rank}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  # Helper function to get display points based on filter
  def display_points({_id, _rank, _name, gp, _pp, _bp, _cs, _ls, _total}, "group"), do: gp
  def display_points({_id, _rank, _name, _gp, pp, _bp, _cs, _ls, _total}, "playoff"), do: pp
  def display_points({_id, _rank, _name, _gp, _pp, _bp, _cs, _ls, total}, _), do: total

  # Build rivalry leaderboard: shows current user and their rivals with stats
  defp build_rivalry_leaderboard(user_id, leaderboard) do
    rivalries = Football.get_user_rivalries(user_id)

    if rivalries == [] do
      []
    else
      leaderboard_map = Map.new(leaderboard, fn {id, rank, name, gp, pp, bp, cs, ls, total} ->
        {id, %{id: id, rank: rank, name: name, group_points: gp, playoff_points: pp, bonus_points: bp, current_streak: cs, longest_streak: ls, total_points: total}}
      end)

      # Get current user from leaderboard
      current_user_data = Map.get(leaderboard_map, user_id)

      # Get rivals from leaderboard
      rival_data = rivalries
      |> Enum.map(fn rivalry ->
        rival = Map.get(leaderboard_map, rivalry.rival_id)
        if rival do
          stats = Football.get_rivalry_stats(user_id, rivalry.rival_id)
          %{
            user: rival,
            rivalry: rivalry,
            stats: stats
          }
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(fn r -> r.user.total_points end, :desc)

      %{
        current_user: current_user_data,
        rivals: rival_data
      }
    end
  end
end

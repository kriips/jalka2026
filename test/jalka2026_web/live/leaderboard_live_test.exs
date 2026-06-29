defmodule Jalka2026Web.LeaderboardLiveTest do
  use Jalka2026Web.ConnCase

  import Phoenix.LiveViewTest

  alias Jalka2026.Leaderboard.Entry
  alias Jalka2026Web.LeaderboardLive.Leaderboard, as: LeaderboardLive

  defp entry(attrs) do
    Entry.new(
      Map.merge(
        %{
          user_id: System.unique_integer([:positive]),
          rank: 0,
          name: "User",
          group_points: 0,
          playoff_points: 0,
          current_streak: 0,
          longest_streak: 0,
          total_points: 0
        },
        attrs
      )
    )
  end

  describe "LeaderboardLive.Leaderboard (public)" do
    test "renders leaderboard page without authentication", %{conn: conn} do
      {:ok, view, html} = live(conn, "/leaderboard")

      assert html =~ "Edetabel"
      assert has_element?(view, "#page-title", "Edetabel")
    end

    test "renders leaderboard with filter controls", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/leaderboard")

      assert has_element?(view, "select[name=sort_by]")
      assert has_element?(view, "select[name=points_filter]")
    end

    test "supports sort_by query parameter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/leaderboard?sort_by=group")

      assert render(view) =~ "Edetabel"
    end

    test "supports points_filter query parameter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/leaderboard?points_filter=group")

      assert render(view) =~ "Edetabel"
    end

    test "filter_change event triggers patch", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/leaderboard")

      assert view
             |> element("form.filter-form")
             |> render_change(%{"sort_by" => "name", "points_filter" => "all"})
    end
  end

  describe "LeaderboardLive.Leaderboard (authenticated)" do
    setup :register_and_log_in_user

    test "renders leaderboard page for logged in user", %{conn: conn} do
      {:ok, view, html} = live(conn, "/leaderboard")

      assert html =~ "Edetabel"
      assert has_element?(view, "#page-title", "Edetabel")
    end
  end

  describe "apply_filters_and_sort/3" do
    setup do
      # Carol has the most points, Alice the fewest — so a points sort and a name
      # sort produce genuinely different orderings.
      leaderboard = [
        entry(%{user_id: 1, name: "Bob", group_points: 4, playoff_points: 1, total_points: 5}),
        entry(%{user_id: 2, name: "Alice", group_points: 1, playoff_points: 1, total_points: 2}),
        entry(%{
          user_id: 3,
          name: "carol",
          group_points: 6,
          playoff_points: 4,
          current_streak: 7,
          total_points: 10
        })
      ]

      %{leaderboard: leaderboard}
    end

    test "sorting by name orders rows alphabetically while every column follows the row", %{
      leaderboard: leaderboard
    } do
      sorted = LeaderboardLive.apply_filters_and_sort(leaderboard, "name", "all")

      # Rows are alphabetical (case-insensitive), not points-descending.
      assert Enum.map(sorted, & &1.name) == ["Alice", "Bob", "carol"]

      # Each row keeps its own data — the points columns travel with the name.
      assert Enum.map(sorted, & &1.total_points) == [2, 5, 10]

      # Rank still reflects the true total-points ranking, independent of order.
      ranks_by_name = Map.new(sorted, &{&1.name, &1.rank})
      assert ranks_by_name == %{"carol" => 1, "Bob" => 2, "Alice" => 3}
    end

    test "sorting by total orders rows by total points descending", %{leaderboard: leaderboard} do
      sorted = LeaderboardLive.apply_filters_and_sort(leaderboard, "total", "all")

      assert Enum.map(sorted, & &1.name) == ["carol", "Bob", "Alice"]
      assert Enum.map(sorted, & &1.rank) == [1, 2, 3]
    end

    test "sorting by streak orders rows by current streak descending", %{leaderboard: leaderboard} do
      sorted = LeaderboardLive.apply_filters_and_sort(leaderboard, "streak", "all")

      assert List.first(sorted).name == "carol"
      assert List.first(sorted).current_streak == 7
    end

    test "group filter ranks by group points regardless of sort order", %{
      leaderboard: leaderboard
    } do
      sorted = LeaderboardLive.apply_filters_and_sort(leaderboard, "name", "group")

      assert Enum.map(sorted, & &1.name) == ["Alice", "Bob", "carol"]
      # Ranks computed from group_points: carol 6 (1), Bob 4 (2), Alice 1 (3).
      ranks_by_name = Map.new(sorted, &{&1.name, &1.rank})
      assert ranks_by_name == %{"carol" => 1, "Bob" => 2, "Alice" => 3}
    end

    test "tied points share the same rank", %{leaderboard: _leaderboard} do
      tied = [
        entry(%{user_id: 10, name: "Dave", total_points: 5}),
        entry(%{user_id: 11, name: "Erin", total_points: 5}),
        entry(%{user_id: 12, name: "Faye", total_points: 3})
      ]

      sorted = LeaderboardLive.apply_filters_and_sort(tied, "total", "all")
      ranks_by_name = Map.new(sorted, &{&1.name, &1.rank})

      assert ranks_by_name["Dave"] == 1
      assert ranks_by_name["Erin"] == 1
      assert ranks_by_name["Faye"] == 3
    end
  end
end

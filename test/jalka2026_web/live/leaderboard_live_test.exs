defmodule Jalka2026Web.LeaderboardLiveTest do
  use Jalka2026Web.ConnCase

  import Phoenix.LiveViewTest

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
end

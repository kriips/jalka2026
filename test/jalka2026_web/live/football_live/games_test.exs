defmodule Jalka2026Web.FootballLive.GamesTest do
  use Jalka2026Web.ConnCase

  import Phoenix.LiveViewTest

  describe "FootballLive.Games (public)" do
    test "renders games page without authentication", %{conn: conn} do
      {:ok, view, html} = live(conn, "/football/games")

      assert html =~ "Alagrupimängud"
      assert has_element?(view, "#page-title", "Alagrupimängud")
    end

    test "renders match table with groups", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/football/games")

      # Pre-seeded data has groups A-L
      assert html =~ "Alagrupp"
    end

    test "toggle_group event expands and collapses group", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/football/games")

      # Toggle group A open
      html = render_click(view, "toggle_group", %{"group" => "Alagrupp A"})
      assert html =~ "Alagrupp A"
    end

    test "show_match event with pre-seeded match", %{conn: conn} do
      # Get a pre-seeded match ID
      [match | _] = Jalka2026.Football.get_matches()

      {:ok, view, _html} = live(conn, "/football/games")

      html = render_click(view, "show_match", %{"id" => to_string(match.id)})
      assert html =~ "Alagrupp"
    end

    test "close_bottom_sheet event", %{conn: conn} do
      [match | _] = Jalka2026.Football.get_matches()

      {:ok, view, _html} = live(conn, "/football/games")

      # Open and then close bottom sheet
      render_click(view, "show_match", %{"id" => to_string(match.id)})
      html = render_click(view, "close_bottom_sheet", %{})
      assert html =~ "Alagrupimängud"
    end
  end
end

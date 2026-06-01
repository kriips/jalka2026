defmodule Jalka2026Web.FootballLive.GameTest do
  use Jalka2026Web.ConnCase

  import Phoenix.LiveViewTest

  describe "FootballLive.Game (public)" do
    test "renders individual game page with pre-seeded match", %{conn: conn} do
      [match | _] = Jalka2026.Football.get_matches()

      {:ok, _view, _html} = live(conn, "/football/games/#{match.id}")
    end

    test "redirects to /football/games for non-existent match", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/football/games"}}} = live(conn, "/football/games/999999")
    end

    test "shows collapsed Ajalugu history dropdown that expands on click", %{conn: conn} do
      [match | _] = Jalka2026.Football.get_matches()

      {:ok, view, html} = live(conn, "/football/games/#{match.id}")

      # Toggle is rendered and the panel is collapsed by default
      assert html =~ "Ajalugu"
      assert html =~ "match-analysis-toggle"
      refute html =~ "match-analysis-panel"

      # Clicking the toggle expands the panel
      html = render_click(element(view, "button.match-analysis-toggle"))
      assert html =~ "match-analysis-panel"
    end
  end
end

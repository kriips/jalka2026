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
  end
end

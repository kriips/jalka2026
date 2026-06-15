defmodule Jalka2026Web.FootballLive.GamesTest do
  use Jalka2026Web.ConnCase

  import Phoenix.LiveViewTest
  import Jalka2026.AccountsFixtures
  import Jalka2026.FootballFixtures

  describe "FootballLive.Games (public)" do
    test "renders games page without authentication", %{conn: conn} do
      {:ok, view, html} = live(conn, "/football/games")

      assert html =~ "Alagrupimängud"
      assert has_element?(view, "#page-title", "Alagrupimängud")
    end

    test "renders match table with groups", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/football/games")

      assert html =~ "Alagrupp"
    end

    test "toggle_group event expands and collapses group", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/football/games")

      html = render_click(view, "toggle_group", %{"group" => "Alagrupp A"})
      assert html =~ "Alagrupp A"
    end

    test "desktop rows are clickable and navigate to game details", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/football/games")

      assert has_element?(view, "tr.match-row-clickable[phx-click]")
      refute has_element?(view, ".view-predictions-btn")
      refute has_element?(view, ".bottom-sheet")
    end

    test "desktop rows show the match's comment count", %{conn: conn} do
      user = user_fixture()
      match = match_fixture()

      {:ok, _} =
        Jalka2026.Chat.create_comment(%{
          content: "Hea mäng!",
          user_id: user.id,
          match_id: match.id
        })

      {:ok, _} =
        Jalka2026.Chat.create_comment(%{content: "Nõus!", user_id: user.id, match_id: match.id})

      {:ok, view, _html} = live(conn, "/football/games")

      assert has_element?(
               view,
               ~s|tr[phx-click*="#{match.id}"] td.match-comments .comment-count|,
               "2"
             )
    end

    test "expanded accordion rows show the comment count when present", %{conn: conn} do
      user = user_fixture()
      match = match_fixture()

      {:ok, _} =
        Jalka2026.Chat.create_comment(%{content: "Tere!", user_id: user.id, match_id: match.id})

      {:ok, view, _html} = live(conn, "/football/games")
      render_click(view, "toggle_group", %{"group" => match.group})

      assert has_element?(
               view,
               ~s|a.group-accordion-match[href="/football/games/#{match.id}"] .comment-count|,
               "1"
             )
    end

    test "expanded accordion matches link to game details", %{conn: conn} do
      [match | _] = Jalka2026.Football.get_matches()
      {:ok, view, _html} = live(conn, "/football/games")

      render_click(view, "toggle_group", %{"group" => match.group})

      assert has_element?(view, ~s|a.group-accordion-match[href="/football/games/#{match.id}"]|)
    end
  end
end

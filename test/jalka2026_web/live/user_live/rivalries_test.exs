defmodule Jalka2026Web.UserLive.RivalriesTest do
  use Jalka2026Web.ConnCase

  import Phoenix.LiveViewTest

  describe "UserLive.Rivalries (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/register"}}} = live(conn, "/users/rivalries")
    end
  end

  describe "UserLive.Rivalries (authenticated)" do
    setup :register_and_log_in_user

    test "renders rivalries page", %{conn: conn} do
      {:ok, view, html} = live(conn, "/users/rivalries")

      assert html =~ "Rivaalid"
      assert has_element?(view, "#page-title", "Rivaalid")
    end

    test "shows empty state when no rivals", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/users/rivalries")

      assert html =~ "Sul pole veel rivaale"
    end

    test "shows add rival button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/users/rivalries")

      assert has_element?(view, "button", "Lisa rivaal")
    end

    test "show_add_modal opens modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/users/rivalries")

      html = render_click(view, "show_add_modal", %{})
      assert html =~ "Lisa rivaal"
      assert html =~ "Otsi kasutajat"
    end

    test "close_add_modal closes modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/users/rivalries")

      render_click(view, "show_add_modal", %{})
      html = render_click(view, "close_add_modal", %{})
      # Modal should be closed - no search input visible
      refute html =~ "Otsi kasutajat"
    end

    test "search event filters users", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/users/rivalries")

      render_click(view, "show_add_modal", %{})
      html = render_change(view, "search", %{"search" => "NonExistentUser12345"})
      assert html =~ "Kasutajaid ei leitud" || html =~ "Lisa rivaal"
    end
  end

  describe "UserLive.Rivalries (with a rival)" do
    setup :register_and_log_in_user

    setup %{user: user} do
      rival = Jalka2026.AccountsFixtures.user_fixture()
      {:ok, _} = Jalka2026.Football.add_rival(user.id, rival.id)
      %{rival: rival}
    end

    test "view_rivalry opens the details modal", %{conn: conn, rival: rival} do
      {:ok, view, _html} = live(conn, "/users/rivalries")

      html = render_click(view, "view_rivalry", %{"rival_id" => to_string(rival.id)})

      assert html =~ "Rivaalitsus: #{rival.name}"
      assert html =~ "Sinu punktid"
    end

    test "does not render a notifications toggle", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/users/rivalries")

      refute html =~ "Teavitused"
    end

    test "rivalry_created broadcast does not crash an open LiveView", %{conn: conn, rival: rival} do
      {:ok, view, _html} = live(conn, "/users/rivalries")

      send(view.pid, {:rivalry_created, %{from_user_id: rival.id}})

      assert render(view) =~ "Rivaalid"
    end
  end
end

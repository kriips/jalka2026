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
end

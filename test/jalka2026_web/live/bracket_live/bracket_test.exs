defmodule Jalka2026Web.BracketLive.BracketTest do
  use Jalka2026Web.ConnCase

  import Phoenix.LiveViewTest

  describe "BracketLive.Bracket (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/register"}}} = live(conn, "/bracket")
    end
  end

  describe "BracketLive.Bracket (authenticated)" do
    setup :register_and_log_in_user

    test "renders bracket page for authenticated user", %{conn: conn} do
      {:ok, view, html} = live(conn, "/bracket")

      assert html =~ "turniiri tabel" || html =~ "Minu turniiri tabel"
      assert has_element?(view, "#page-title")
    end

    test "displays bracket stats", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/bracket")

      assert html =~ "Punktid"
      assert html =~ "Täpsus"
      assert html =~ "Õiged"
    end

    test "displays bracket legend with point values", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/bracket")

      assert html =~ "Punktid ringide kaupa"
      assert html =~ "32 parimat"
      assert html =~ "Veerandfinaal"
      assert html =~ "Finaal"
    end
  end
end

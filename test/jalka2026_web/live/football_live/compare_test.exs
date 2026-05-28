defmodule Jalka2026Web.FootballLive.CompareTest do
  use Jalka2026Web.ConnCase

  import Phoenix.LiveViewTest

  describe "FootballLive.Compare (public)" do
    test "renders compare page without user selection", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/football/compare")

      # Compare page should render with user selection dropdowns
      assert html =~ "Võrdle" || html =~ "compare" || html =~ "Vali"
    end

    test "renders compare page with user selection", %{conn: conn} do
      user1 = Jalka2026.AccountsFixtures.user_fixture()
      user2 = Jalka2026.AccountsFixtures.user_fixture()

      {:ok, _view, html} =
        live(conn, "/football/compare?user1=#{user1.id}&user2=#{user2.id}")

      assert html =~ user1.name || html =~ user2.name || html =~ "Võrdle"
    end
  end
end

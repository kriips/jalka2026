defmodule Jalka2026Web.FootballLive.UserTest do
  use Jalka2026Web.ConnCase

  import Phoenix.LiveViewTest

  describe "FootballLive.User (public)" do
    test "renders user profile page", %{conn: conn} do
      user = Jalka2026.AccountsFixtures.user_fixture()

      {:ok, _view, html} = live(conn, "/football/user/#{user.id}")

      assert html =~ user.name
    end
  end
end

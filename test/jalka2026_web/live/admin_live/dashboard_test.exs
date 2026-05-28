defmodule Jalka2026Web.AdminLive.DashboardTest do
  use Jalka2026Web.ConnCase

  import Phoenix.LiveViewTest

  describe "AdminLive.Dashboard (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/register"}}} = live(conn, "/admin")
    end
  end

  describe "AdminLive.Dashboard (non-admin user)" do
    setup :register_and_log_in_user

    test "redirects non-admin user away from admin", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/admin")
    end
  end

  describe "AdminLive.Dashboard (admin user)" do
    setup %{conn: conn} do
      user = Jalka2026.AccountsFixtures.user_fixture()

      # Make user admin
      user
      |> Ecto.Changeset.change(%{is_admin: true})
      |> Jalka2026.Repo.update!()

      admin_user = Jalka2026.Repo.get!(Jalka2026.Accounts.User, user.id)
      %{conn: log_in_user(conn, admin_user), user: admin_user}
    end

    test "renders admin dashboard for admin user", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin")

      # Admin dashboard should render
      assert html =~ "admin" || html =~ "Admin" || html =~ "dashboard" || html =~ "Mängud" ||
               html =~ "Kasutajad"
    end
  end
end

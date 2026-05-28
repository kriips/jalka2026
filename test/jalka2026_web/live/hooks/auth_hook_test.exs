defmodule Jalka2026Web.Hooks.AuthHookTest do
  use Jalka2026Web.ConnCase

  import Phoenix.LiveViewTest

  describe "AuthHook :assign_user" do
    test "public pages work without authentication", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "MM 2026"
    end

    test "public pages work with authentication", %{conn: conn} do
      user = Jalka2026.AccountsFixtures.user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, "/")
      assert html =~ "MM 2026"
    end
  end

  describe "AuthHook :require_user" do
    test "redirects to login for unauthenticated user on protected routes", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/register"}}} = live(conn, "/bracket")
    end

    test "allows authenticated user to access protected routes", %{conn: conn} do
      user = Jalka2026.AccountsFixtures.user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _view, _html} = live(conn, "/bracket")
    end
  end

  describe "AuthHook :require_admin" do
    test "redirects to login for unauthenticated user on admin routes", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/register"}}} = live(conn, "/admin")
    end

    test "redirects non-admin user away from admin routes", %{conn: conn} do
      user = Jalka2026.AccountsFixtures.user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/admin")
    end

    test "allows admin user to access admin routes", %{conn: conn} do
      user = Jalka2026.AccountsFixtures.user_fixture()

      user
      |> Ecto.Changeset.change(%{is_admin: true})
      |> Jalka2026.Repo.update!()

      admin_user = Jalka2026.Repo.get!(Jalka2026.Accounts.User, user.id)
      conn = log_in_user(conn, admin_user)

      {:ok, _view, _html} = live(conn, "/admin")
    end
  end
end

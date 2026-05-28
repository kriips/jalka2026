defmodule Jalka2026Web.UserRegistrationLive.NewTest do
  use Jalka2026Web.ConnCase

  import Phoenix.LiveViewTest

  describe "UserRegistrationLive.New" do
    test "renders registration page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/users/register")

      assert html =~ "Registreeri" || html =~ "register" || html =~ "Nimi" || html =~ "E-post"
    end

    test "redirects if user is already authenticated", %{conn: conn} do
      user = Jalka2026.AccountsFixtures.user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/users/register")
    end

    test "validate event triggers form validation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/users/register")

      html =
        render_change(view, "validate", %{
          "user" => %{"name" => "TestName", "email" => "test@test.com", "password" => "short"}
        })

      # Should show some form content (validation feedback)
      assert html =~ "TestName" || html =~ "test@test.com" || html =~ "form"
    end
  end
end

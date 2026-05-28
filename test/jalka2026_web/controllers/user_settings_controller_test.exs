defmodule Jalka2026Web.UserSettingsControllerTest do
  use Jalka2026Web.ConnCase, async: true

  alias Jalka2026.Accounts
  alias Jalka2026.Repo
  import Jalka2026.AccountsFixtures

  setup context do
    # Register and log in user
    %{conn: conn, user: user} = register_and_log_in_user(context)
    # Add email to user for email-related tests
    {:ok, user_with_email} = Repo.update(Ecto.Changeset.change(user, email: unique_user_email()))
    %{conn: conn, user: user_with_email}
  end

  describe "GET /users/settings" do
    test "renders settings page", %{conn: conn} do
      conn = get(conn, Routes.user_settings_path(conn, :edit))
      response = html_response(conn, 200)
      assert response =~ "<h1>Settings</h1>"
    end

    test "redirects if user is not logged in" do
      conn = build_conn()
      conn = get(conn, Routes.user_settings_path(conn, :edit))
      # App redirects to registration page when not authenticated
      assert redirected_to(conn) == Routes.user_registration_new_path(conn, :new)
    end
  end

  describe "PUT /users/settings (change password form)" do
    test "updates the user password and resets tokens", %{conn: conn, user: user} do
      new_password_conn =
        put(conn, Routes.user_settings_path(conn, :update), %{
          "action" => "update_password",
          "current_password" => valid_user_password(),
          "user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(new_password_conn) == Routes.user_settings_path(conn, :edit)
      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_user_by_name_and_password(user.name, "new valid password")
    end

    test "does not update password on invalid data", %{conn: conn} do
      old_password_conn =
        put(conn, Routes.user_settings_path(conn, :update), %{
          "action" => "update_password",
          "current_password" => "invalid",
          "user" => %{
            "password" => "1234",
            "password_confirmation" => "does not match"
          }
        })

      response = html_response(old_password_conn, 200)
      assert response =~ "<h1>Settings</h1>"
      assert response =~ "peab olema vähemalt 5 tähemärki"
      assert response =~ "paroolid ei kattu"
      assert response =~ "on vale"

      assert get_session(old_password_conn, :user_token) == get_session(conn, :user_token)
    end
  end

  describe "PUT /users/settings (change email form)" do
    @tag :capture_log
    test "updates the user email", %{conn: conn, user: user} do
      conn =
        put(conn, Routes.user_settings_path(conn, :update), %{
          "action" => "update_email",
          "current_password" => valid_user_password(),
          "user" => %{"email" => unique_user_email()}
        })

      assert redirected_to(conn) == Routes.user_settings_path(conn, :edit)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "A link to confirm your email"
      assert Accounts.get_user_by_email(user.email)
    end

    test "does not update email on invalid data", %{conn: conn} do
      conn =
        put(conn, Routes.user_settings_path(conn, :update), %{
          "action" => "update_email",
          "current_password" => "invalid",
          "user" => %{"email" => "with spaces"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Settings</h1>"
      assert response =~ "peab sisaldama @ märki ja mitte tühikuid"
      assert response =~ "on vale"
    end
  end

  describe "GET /users/settings/confirm_email/:token" do
    setup %{user: user} do
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{token: token, email: email}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.user_settings_path(conn, :edit)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Email changed successfully"
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.user_settings_path(conn, :edit)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Email change link is invalid or it has expired"
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, "oops"))
      assert redirected_to(conn) == Routes.user_settings_path(conn, :edit)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Email change link is invalid or it has expired"

      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      conn = get(conn, Routes.user_settings_path(conn, :confirm_email, token))
      # App redirects to registration page when not authenticated
      assert redirected_to(conn) == Routes.user_registration_new_path(conn, :new)
    end
  end

  describe "PUT /users/settings/theme" do
    test "updates theme to dark", %{conn: conn} do
      conn = put(conn, "/users/settings/theme", %{"theme" => "dark"})
      assert json_response(conn, 200) == %{"ok" => true, "theme" => "dark"}
    end

    test "updates theme to light", %{conn: conn} do
      conn = put(conn, "/users/settings/theme", %{"theme" => "light"})
      assert json_response(conn, 200) == %{"ok" => true, "theme" => "light"}
    end

    test "rejects invalid theme", %{conn: conn} do
      conn = put(conn, "/users/settings/theme", %{"theme" => "rainbow"})
      assert json_response(conn, 422) == %{"error" => "invalid theme"}
    end

    test "rejects missing theme param", %{conn: conn} do
      conn = put(conn, "/users/settings/theme", %{})
      assert json_response(conn, 422) == %{"error" => "invalid theme"}
    end
  end
end

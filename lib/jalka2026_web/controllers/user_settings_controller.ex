defmodule Jalka2026Web.UserSettingsController do
  use Jalka2026Web, :controller

  alias Jalka2026.Accounts
  alias Jalka2026Web.UserAuth

  plug :assign_email_and_password_changesets when action not in [:update_theme]

  def edit(conn, _params) do
    render(conn, "edit.html")
  end

  def update(conn, %{"action" => "update_email"} = params) do
    %{"current_password" => password, "user" => user_params} = params
    user = conn.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_update_email_instructions(
          applied_user,
          user.email,
          &Routes.user_settings_url(conn, :confirm_email, &1)
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: Routes.user_settings_path(conn, :edit))

      {:error, changeset} ->
        render(conn, "edit.html", email_changeset: changeset)
    end
  end

  def update(conn, %{"action" => "update_password"} = params) do
    %{"current_password" => password, "user" => user_params} = params
    user = conn.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:user_return_to, Routes.user_settings_path(conn, :edit))
        |> UserAuth.log_in_user(user)

      {:error, changeset} ->
        render(conn, "edit.html", password_changeset: changeset)
    end
  end

  def update_theme(conn, %{"theme" => theme}) when theme in ["light", "dark"] do
    user = conn.assigns.current_user

    case Accounts.update_user_theme(user, theme) do
      {:ok, _user} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{ok: true, theme: theme}))

      {:error, _changeset} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(422, Jason.encode!(%{error: "invalid theme"}))
    end
  end

  def update_theme(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(422, Jason.encode!(%{error: "invalid theme"}))
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.update_user_email(conn.assigns.current_user, token) do
      :ok ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: Routes.user_settings_path(conn, :edit))

      :error ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: Routes.user_settings_path(conn, :edit))
    end
  end

  defp assign_email_and_password_changesets(conn, _opts) do
    user = conn.assigns.current_user

    conn
    |> assign(:email_changeset, Accounts.change_user_email(user))
    |> assign(:password_changeset, Accounts.change_user_password(user))
  end
end

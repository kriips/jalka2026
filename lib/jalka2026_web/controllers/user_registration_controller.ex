defmodule Jalka2026Web.UserRegistrationController do
  use Jalka2026Web, :controller

  alias Jalka2026.Accounts
  alias Jalka2026.Accounts.User
  alias Jalka2026.Leaderboard
  alias Jalka2026Web.UserAuth

  def new(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Recalculate leaderboard asynchronously to include the new user
        Leaderboard.recalc_leaderboard_async()

        conn
        |> put_flash(:info, "Kasutaja loodud.")
        |> put_session(:user_return_to, "/football/predict")
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = _changeset} ->
        conn
        |> redirect(to: Routes.user_session_path(conn, :new))
    end
  end
end

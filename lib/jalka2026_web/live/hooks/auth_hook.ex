defmodule Jalka2026Web.Hooks.AuthHook do
  @moduledoc """
  LiveView on_mount hook that extracts `current_user` from the session token.

  ## Modes

    * `:assign_user`   – assigns `current_user` (may be nil for public pages)
    * `:require_user`  – redirects to login when no user is found
    * `:require_admin` – redirects unless user is an admin
  """

  import Phoenix.LiveView
  import Phoenix.Component, only: [assign_new: 3]

  alias Jalka2026.Accounts
  alias Jalka2026.Accounts.User
  alias Jalka2026Web.Router.Helpers, as: Routes

  def on_mount(:assign_user, _params, session, socket) do
    {:cont, assign_current_user(socket, session)}
  end

  def on_mount(:require_user, _params, session, socket) do
    socket = assign_current_user(socket, session)

    case socket.assigns.current_user do
      %User{} ->
        {:cont, socket}

      _other ->
        {:halt,
         socket
         |> put_flash(:error, "Selle lehe nägemiseks pead sisse logima")
         |> redirect(to: Routes.user_session_path(socket, :new))}
    end
  end

  def on_mount(:require_admin, _params, session, socket) do
    socket = assign_current_user(socket, session)

    case socket.assigns.current_user do
      %User{} = user ->
        if User.admin?(user) do
          {:cont, socket}
        else
          {:halt,
           socket
           |> put_flash(:error, "Sellele lehele ligipääs on keelatud")
           |> redirect(to: "/")}
        end

      _other ->
        {:halt,
         socket
         |> put_flash(:error, "Selle lehe nägemiseks pead sisse logima")
         |> redirect(to: Routes.user_session_path(socket, :new))}
    end
  end

  defp assign_current_user(socket, session) do
    assign_new(socket, :current_user, fn ->
      with user_token when not is_nil(user_token) <- session["user_token"],
           %User{} = user <- Accounts.get_user_by_session_token(user_token) do
        user
      else
        _ -> nil
      end
    end)
  end
end

defmodule Jalka2026Web.PageLive do
  use Jalka2026Web, :live_view

  alias Jalka2026.{Accounts, Competitions}

  @impl true
  def mount(_params, session, socket) do
    current_user = find_current_user(session)
    competition = Competitions.current()
    {:ok, assign(socket, query: "", results: %{}, current_user: current_user, competition: competition)}
  end

  defp find_current_user(session) do
    with user_token when not is_nil(user_token) <- session["user_token"],
         %Accounts.User{} = user <- Accounts.get_user_by_session_token(user_token),
         do: user
  end

  @impl true
  def handle_event("suggest", %{"q" => query}, socket) do
    {:noreply, assign(socket, results: search(query), query: query)}
  end

  defp search(query) do
    for {app, desc, vsn} <- Application.started_applications(),
        app = to_string(app),
        String.starts_with?(app, query) and not List.starts_with?(desc, ~c"ERTS"),
        into: %{},
        do: {app, vsn}
  end
end

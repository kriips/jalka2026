defmodule Jalka2026Web.UserSocket do
  use Phoenix.Socket

  alias Jalka2026.Accounts

  ## Channels
  channel "match_chat:*", Jalka2026Web.MatchChatChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Phoenix.Token.verify(Jalka2026Web.Endpoint, "user socket", token, max_age: 86400) do
      {:ok, user_id} ->
        case Accounts.get_user(user_id) do
          nil -> :error
          user -> {:ok, assign(socket, :current_user, user)}
        end

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end

defmodule Jalka2026Web.MatchChatChannel do
  use Phoenix.Channel

  alias Jalka2026.Chat
  alias Jalka2026.Football

  @impl true
  def join("match_chat:" <> match_id, _payload, socket) do
    case Integer.parse(match_id) do
      {id, ""} ->
        case Football.get_match(id) do
          nil ->
            {:error, %{reason: "match not found"}}

          match ->
            comments = Chat.list_comments(id)
            {:ok, %{comments: format_comments(comments)}, assign(socket, :match_id, match.id)}
        end

      _ ->
        {:error, %{reason: "invalid match id"}}
    end
  end

  @impl true
  def handle_in("new_message", %{"content" => content}, socket) do
    user = socket.assigns.current_user
    match_id = socket.assigns.match_id

    case Jalka2026Web.LiveRateLimiter.check_chat_rate(user.id) do
      :ok ->
        case Chat.create_comment(%{content: content, user_id: user.id, match_id: match_id}) do
          {:ok, comment} ->
            broadcast!(socket, "new_message", format_comment(comment))
            {:reply, :ok, socket}

          {:error, _changeset} ->
            {:reply, {:error, %{reason: "could not create message"}}, socket}
        end

      {:error, :rate_limited} ->
        {:reply, {:error, %{reason: "too many messages, please wait"}}, socket}
    end
  end

  def handle_in("delete_message", %{"id" => comment_id}, socket) do
    user = socket.assigns.current_user

    case Chat.get_comment!(comment_id) do
      nil ->
        {:reply, {:error, %{reason: "comment not found"}}, socket}

      comment ->
        case Chat.delete_comment(comment, user) do
          {:ok, _} ->
            broadcast!(socket, "delete_message", %{id: comment_id})
            {:reply, :ok, socket}

          {:error, :unauthorized} ->
            {:reply, {:error, %{reason: "unauthorized"}}, socket}

          {:error, _} ->
            {:reply, {:error, %{reason: "could not delete message"}}, socket}
        end
    end
  end

  defp format_comments(comments) do
    Enum.map(comments, &format_comment/1)
  end

  defp format_comment(comment) do
    %{
      id: comment.id,
      content: comment.content,
      user_id: comment.user_id,
      username: comment.user.username,
      inserted_at: NaiveDateTime.to_iso8601(comment.inserted_at)
    }
  end
end

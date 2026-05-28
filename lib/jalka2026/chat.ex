defmodule Jalka2026.Chat do
  @moduledoc """
  The Chat context for managing match comments and real-time chat functionality.

  Functions return `%Comment{}` structs (with `:user` preloaded).
  Subscribe to `"match_chat:<match_id>"` via `subscribe/1` for real-time updates.
  """

  import Ecto.Query, warn: false

  alias Jalka2026.Chat.Comment
  alias Jalka2026.Repo

  @type comment :: Comment.t()

  @topic_prefix "match_chat:"

  @doc """
  Returns the list of comments for a match, ordered by insertion time.
  """
  def list_comments(match_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Comment
    |> where([c], c.match_id == ^match_id)
    |> order_by([c], desc: c.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Gets a single comment.
  """
  def get_comment!(id), do: Repo.get!(Comment, id) |> Repo.preload(:user)

  @doc """
  Creates a comment and broadcasts it to subscribers.
  """
  def create_comment(attrs \\ %{}) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, comment} ->
        comment = Repo.preload(comment, :user)
        broadcast_comment(comment)
        {:ok, comment}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a comment. Only the comment owner or admin can delete.
  """
  def delete_comment(%Comment{} = comment, user) do
    if can_delete?(comment, user) do
      Repo.delete(comment)
      |> case do
        {:ok, deleted_comment} ->
          broadcast_delete(deleted_comment)
          {:ok, deleted_comment}

        error ->
          error
      end
    else
      {:error, :unauthorized}
    end
  end

  defp can_delete?(comment, user) do
    comment.user_id == user.id || Jalka2026.Accounts.User.admin?(user)
  end

  @doc """
  Subscribe to match chat updates.
  """
  def subscribe(match_id) do
    Phoenix.PubSub.subscribe(Jalka2026.PubSub, topic(match_id))
  end

  @doc """
  Unsubscribe from match chat updates.
  """
  def unsubscribe(match_id) do
    Phoenix.PubSub.unsubscribe(Jalka2026.PubSub, topic(match_id))
  end

  defp topic(match_id), do: "#{@topic_prefix}#{match_id}"

  defp broadcast_comment(comment) do
    Phoenix.PubSub.broadcast(
      Jalka2026.PubSub,
      topic(comment.match_id),
      {:new_comment, comment}
    )
  end

  defp broadcast_delete(comment) do
    Phoenix.PubSub.broadcast(
      Jalka2026.PubSub,
      topic(comment.match_id),
      {:delete_comment, comment.id}
    )
  end
end

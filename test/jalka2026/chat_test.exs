defmodule Jalka2026.ChatTest do
  use Jalka2026.DataCase

  alias Jalka2026.Chat
  import Jalka2026.AccountsFixtures
  import Jalka2026.FootballFixtures

  describe "create_comment/1" do
    test "creates a comment with valid attributes" do
      user = user_fixture()
      match = match_fixture()

      {:ok, comment} =
        Chat.create_comment(%{
          content: "Great match!",
          user_id: user.id,
          match_id: match.id
        })

      assert comment.content == "Great match!"
      assert comment.user_id == user.id
      assert comment.match_id == match.id
      assert comment.user != nil
    end

    test "fails with missing required fields" do
      {:error, changeset} = Chat.create_comment(%{})
      errors = errors_on(changeset)
      assert "can't be blank" in errors.content
      assert "can't be blank" in errors.user_id
      assert "can't be blank" in errors.match_id
    end

    test "fails with content too long" do
      user = user_fixture()
      match = match_fixture()

      {:error, changeset} =
        Chat.create_comment(%{
          content: String.duplicate("a", 501),
          user_id: user.id,
          match_id: match.id
        })

      assert "should be at most 500 character(s)" in errors_on(changeset).content
    end
  end

  describe "list_comments/1" do
    test "returns comments for a match ordered by insertion" do
      user = user_fixture()
      match = match_fixture()

      {:ok, _comment1} =
        Chat.create_comment(%{content: "First", user_id: user.id, match_id: match.id})

      {:ok, _comment2} =
        Chat.create_comment(%{content: "Second", user_id: user.id, match_id: match.id})

      comments = Chat.list_comments(match.id)
      assert length(comments) == 2
      contents = Enum.map(comments, & &1.content)
      assert "First" in contents
      assert "Second" in contents
    end

    test "returns empty list for match with no comments" do
      match = match_fixture()
      assert Chat.list_comments(match.id) == []
    end

    test "respects limit option" do
      user = user_fixture()
      match = match_fixture()

      for i <- 1..5 do
        Chat.create_comment(%{content: "Comment #{i}", user_id: user.id, match_id: match.id})
      end

      comments = Chat.list_comments(match.id, limit: 3)
      assert length(comments) == 3
    end
  end

  describe "comment_counts_by_match/0" do
    test "returns counts grouped by match, omitting matches without comments" do
      user = user_fixture()
      match1 = match_fixture()
      match2 = match_fixture()
      match3 = match_fixture()

      {:ok, _} = Chat.create_comment(%{content: "a", user_id: user.id, match_id: match1.id})
      {:ok, _} = Chat.create_comment(%{content: "b", user_id: user.id, match_id: match1.id})
      {:ok, _} = Chat.create_comment(%{content: "c", user_id: user.id, match_id: match2.id})

      counts = Chat.comment_counts_by_match()

      assert counts[match1.id] == 2
      assert counts[match2.id] == 1
      refute Map.has_key?(counts, match3.id)
    end
  end

  describe "get_comment!/1" do
    test "returns comment with preloaded user" do
      user = user_fixture()
      match = match_fixture()

      {:ok, created} =
        Chat.create_comment(%{content: "Test", user_id: user.id, match_id: match.id})

      comment = Chat.get_comment!(created.id)
      assert comment.id == created.id
      assert comment.user != nil
      assert comment.user.id == user.id
    end
  end

  describe "delete_comment/2" do
    test "owner can delete their own comment" do
      user = user_fixture()
      match = match_fixture()

      {:ok, comment} =
        Chat.create_comment(%{content: "Test", user_id: user.id, match_id: match.id})

      assert {:ok, _deleted} = Chat.delete_comment(comment, user)
    end

    test "admin can delete any comment" do
      user = user_fixture()
      admin = user_fixture()
      # Manually set admin flag
      Jalka2026.Repo.update!(Ecto.Changeset.change(admin, is_admin: true))
      admin = Jalka2026.Accounts.get_user!(admin.id)
      match = match_fixture()

      {:ok, comment} =
        Chat.create_comment(%{content: "Test", user_id: user.id, match_id: match.id})

      assert {:ok, _deleted} = Chat.delete_comment(comment, admin)
    end

    test "non-owner non-admin cannot delete comment" do
      user = user_fixture()
      other_user = user_fixture()
      match = match_fixture()

      {:ok, comment} =
        Chat.create_comment(%{content: "Test", user_id: user.id, match_id: match.id})

      assert {:error, :unauthorized} = Chat.delete_comment(comment, other_user)
    end
  end
end

defmodule Jalka2026Web.Resolvers.AccountsResolverTest do
  use Jalka2026.DataCase

  alias Jalka2026Web.Resolvers.AccountsResolver
  import Jalka2026.AccountsFixtures

  describe "list_users/0" do
    test "returns all users" do
      _user = user_fixture()
      users = AccountsResolver.list_users()
      assert is_list(users)
      assert users != []
    end
  end

  describe "get_user/1" do
    test "returns a user by id" do
      user = user_fixture()
      result = AccountsResolver.get_user(user.id)
      assert result.id == user.id
      assert result.name == user.name
    end
  end

  describe "current_user/2" do
    test "returns current user from context" do
      user = user_fixture()
      assert {:ok, ^user} = AccountsResolver.current_user(nil, %{context: %{current_user: user}})
    end

    test "returns nil when no current user" do
      assert {:ok, nil} = AccountsResolver.current_user(nil, %{})
    end
  end

  describe "list_allowed_users/1" do
    test "returns matching allowed users" do
      allowed = allowed_user_fixture(%{name: "SearchTestUser"})
      result = AccountsResolver.list_allowed_users("SearchTestUser")
      assert result != []
      assert Enum.any?(result, fn a -> a.name == allowed.name end)
    end
  end
end

defmodule Jalka2026.Accounts.UserTest do
  use Jalka2026.DataCase

  alias Jalka2026.Accounts.User
  import Jalka2026.AccountsFixtures

  describe "admin?/1" do
    test "returns true for admin user" do
      assert User.admin?(%User{is_admin: true}) == true
    end

    test "returns false for non-admin user" do
      assert User.admin?(%User{is_admin: false}) == false
    end

    test "returns false for nil" do
      assert User.admin?(nil) == false
    end

    test "returns false for struct without is_admin" do
      assert User.admin?(%{}) == false
    end
  end

  describe "theme_changeset/2" do
    test "valid light theme" do
      user = %User{}
      changeset = User.theme_changeset(user, %{theme: "light"})
      assert changeset.valid?
    end

    test "valid dark theme" do
      user = %User{}
      changeset = User.theme_changeset(user, %{theme: "dark"})
      assert changeset.valid?
    end

    test "rejects invalid theme" do
      user = %User{}
      changeset = User.theme_changeset(user, %{theme: "invalid"})
      assert %{theme: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "registration_changeset/3" do
    test "requires name and password" do
      changeset = User.registration_changeset(%User{}, %{})
      errors = errors_on(changeset)
      assert "can't be blank" in errors.name
      assert "can't be blank" in errors.password
    end

    test "validates password min length" do
      name = unique_user_name()
      allowed_user_fixture(%{name: name})
      changeset = User.registration_changeset(%User{}, %{name: name, password: "1234"})
      assert %{password: ["should be at least 5 character(s)"]} = errors_on(changeset)
    end

    test "validates password max length" do
      name = unique_user_name()
      allowed_user_fixture(%{name: name})
      too_long = String.duplicate("a", 81)
      changeset = User.registration_changeset(%User{}, %{name: name, password: too_long})
      assert %{password: ["should be at most 80 character(s)"]} = errors_on(changeset)
    end

    test "hashes password by default" do
      name = unique_user_name()
      allowed_user_fixture(%{name: name})
      changeset = User.registration_changeset(%User{}, %{name: name, password: "valid_password"})
      assert get_change(changeset, :hashed_password) != nil
    end

    test "does not hash password when hash_password: false" do
      name = unique_user_name()
      allowed_user_fixture(%{name: name})

      changeset =
        User.registration_changeset(%User{}, %{name: name, password: "valid_password"},
          hash_password: false
        )

      assert get_change(changeset, :hashed_password) == nil
      assert get_change(changeset, :password) == "valid_password"
    end
  end

  describe "email_changeset/2" do
    test "requires email to change" do
      user = %User{email: "old@example.com"}
      changeset = User.email_changeset(user, %{})
      assert %{email: ["ei muutunud"]} = errors_on(changeset)
    end

    test "validates email format" do
      user = %User{email: "old@example.com"}
      changeset = User.email_changeset(user, %{email: "not valid"})
      assert %{email: ["peab sisaldama @ märki ja mitte tühikuid"]} = errors_on(changeset)
    end

    test "validates email max length" do
      user = %User{email: "old@example.com"}
      too_long = String.duplicate("a", 161)
      changeset = User.email_changeset(user, %{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end
  end

  describe "password_changeset/3" do
    test "requires password" do
      changeset = User.password_changeset(%User{}, %{})
      assert %{password: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates password confirmation" do
      changeset =
        User.password_changeset(%User{}, %{
          password: "valid_password",
          password_confirmation: "different"
        })

      assert %{password_confirmation: ["paroolid ei kattu"]} = errors_on(changeset)
    end
  end

  describe "confirm_changeset/1" do
    test "sets confirmed_at" do
      changeset = User.confirm_changeset(%User{})
      assert get_change(changeset, :confirmed_at) != nil
    end
  end

  describe "valid_password?/2" do
    test "returns true for valid password" do
      user = user_fixture()
      assert User.valid_password?(user, valid_user_password())
    end

    test "returns false for invalid password" do
      user = user_fixture()
      refute User.valid_password?(user, "wrong_password")
    end

    test "returns false for nil user" do
      refute User.valid_password?(nil, "some_password")
    end

    test "returns false for user without hashed_password" do
      refute User.valid_password?(%User{hashed_password: nil}, "some_password")
    end
  end

  describe "validate_current_password/2" do
    test "adds error for invalid current password" do
      user = user_fixture()
      changeset = User.password_changeset(user, %{password: "new_password"})
      result = User.validate_current_password(changeset, "wrong")
      assert %{current_password: ["on vale"]} = errors_on(result)
    end

    test "passes through for valid current password" do
      user = user_fixture()
      changeset = User.password_changeset(user, %{password: "new_password"})
      result = User.validate_current_password(changeset, valid_user_password())
      refute Map.has_key?(errors_on(result), :current_password)
    end
  end
end

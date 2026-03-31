defmodule Jalka2026.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Jalka2026.Accounts` context.
  """

  alias Jalka2026.Repo
  alias Jalka2026.Accounts.AllowedUser

  def unique_user_name, do: "TestUser#{System.unique_integer([:positive])}"
  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    name = attrs[:name] || unique_user_name()

    Enum.into(attrs, %{
      name: name,
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  @doc """
  Creates an allowed_user entry (whitelist) for test users.
  """
  def allowed_user_fixture(attrs \\ %{}) do
    name = attrs[:name] || unique_user_name()

    {:ok, allowed_user} =
      %AllowedUser{}
      |> AllowedUser.changeset(%{name: name})
      |> Repo.insert()

    allowed_user
  end

  def user_fixture(attrs \\ %{}) do
    name = attrs[:name] || unique_user_name()

    # First create the allowed_user entry (whitelist)
    _allowed = allowed_user_fixture(%{name: name})

    {:ok, user} =
      attrs
      |> Map.put(:name, name)
      |> valid_user_attributes()
      |> Jalka2026.Accounts.register_user()

    user
  end

  def extract_user_token(fun) do
    {:ok, captured} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    # Support both old-style map with :body and Bamboo.Email with :text_body
    body = case captured do
      %Bamboo.Email{text_body: text_body} -> text_body
      %{body: body} -> body
      %{text_body: text_body} -> text_body
    end
    [_, token, _] = String.split(body, "[TOKEN]")
    token
  end
end

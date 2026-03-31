defmodule Jalka2026.Football.UserStreak do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_streaks" do
    belongs_to(:user, Jalka2026.Accounts.User)
    field(:current_streak, :integer, default: 0)
    field(:longest_streak, :integer, default: 0)
    field(:bonus_points, :integer, default: 0)

    timestamps()
  end

  @doc false
  def changeset(user_streak, attrs) do
    user_streak
    |> cast(attrs, [:user_id, :current_streak, :longest_streak, :bonus_points])
    |> validate_required([:user_id])
    |> validate_number(:current_streak, greater_than_or_equal_to: 0)
    |> validate_number(:longest_streak, greater_than_or_equal_to: 0)
    |> validate_number(:bonus_points, greater_than_or_equal_to: 0)
    |> unique_constraint(:user_id)
  end
end

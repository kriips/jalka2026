defmodule Jalka2026.Football.UserFavoriteTeam do
  use Ecto.Schema
  import Ecto.Changeset

  alias Jalka2026.Accounts.User
  alias Jalka2026.Football.Team

  schema "user_favorite_teams" do
    field(:is_primary, :boolean, default: false)

    belongs_to(:user, User)
    belongs_to(:team, Team)

    timestamps()
  end

  @doc false
  def changeset(favorite_team, attrs) do
    favorite_team
    |> cast(attrs, [:user_id, :team_id, :is_primary])
    |> validate_required([:user_id, :team_id])
    |> unique_constraint([:user_id, :team_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:team_id)
  end
end

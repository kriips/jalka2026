defmodule Jalka2026.Football.PlayoffPrediction do
  use Ecto.Schema
  import Ecto.Changeset

  alias Jalka2026.Accounts.User
  alias Jalka2026.Football.Team
  alias Jalka2026.Repo

  schema "playoff_predictions" do
    belongs_to(:user, User)
    belongs_to(:team, Team)
    field(:phase, :integer)

    timestamps()
  end

  @doc false
  def changeset(playoff_prediction, attrs) do
    playoff_prediction
    |> cast(attrs, [:user_id, :team_id, :phase])
  end

  def get_playoff_prediction!(id) do
    Repo.get!(__MODULE__, id)
  end

  @doc false
  def create_changeset(playoff_prediction, attrs) do
    playoff_prediction
    |> cast(attrs, [:user_id, :team_id, :phase])
    |> cast_assoc(:user)
    |> assoc_constraint(:user)
    |> cast_assoc(:team)
    |> assoc_constraint(:team)
  end
end

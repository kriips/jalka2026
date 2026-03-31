defmodule Jalka2026.Football.PlayoffResult do
  use Ecto.Schema
  import Ecto.Changeset

  alias Jalka2026.Football.{Team, Competition}
  alias Jalka2026.Repo

  schema "playoff_results" do
    belongs_to(:team, Team)
    field(:phase, :integer)
    belongs_to(:competition, Competition, type: :string)

    timestamps()
  end

  @doc false
  def changeset(playoff_result, attrs) do
    playoff_result
    |> cast(attrs, [:phase, :team, :competition_id])
  end

  def get_playoff_result!(id) do
    Repo.get!(PlayoffResult, id)
  end

  @doc false
  def create_changeset(playoff_result, attrs) do
    playoff_result
    |> cast(attrs, [:team_id, :phase, :competition_id])
    |> cast_assoc(:team)
    |> assoc_constraint(:team)
  end
end

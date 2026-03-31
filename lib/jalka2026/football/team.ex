defmodule Jalka2026.Football.Team do
  use Ecto.Schema
  import Ecto.Changeset

  alias Jalka2026.Repo
  alias Jalka2026.Football.{PlayoffPrediction, Competition}

  schema "teams" do
    field(:name, :string)
    field(:code, :string)
    field(:flag, :string)
    field(:group, :string)
    belongs_to(:competition, Competition, type: :string)

    many_to_many(:playoff_predictions, PlayoffPrediction,
      join_through: "playoff_predictions_teams"
    )

    timestamps()
  end

  @valid_groups ~w(A B C D E F G H I J K L)

  @doc false
  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :code, :flag, :id, :group, :competition_id])
    |> validate_inclusion(:group, @valid_groups)
  end

  def get_team!(id), do: Repo.get!(Team, id)
end

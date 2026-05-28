defmodule Jalka2026.Football.Team do
  use Ecto.Schema
  import Ecto.Changeset

  alias Jalka2026.Football.{Competition, PlayoffPrediction}
  alias Jalka2026.Repo

  @type t :: %__MODULE__{
          id: pos_integer() | nil,
          name: String.t() | nil,
          code: String.t() | nil,
          flag: String.t() | nil,
          group: String.t() | nil,
          competition_id: String.t() | nil
        }

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

  @doc false
  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :code, :flag, :id, :group, :competition_id])
    |> validate_inclusion(:group, Jalka2026.Football.groups())
  end

  def get_team!(id), do: Repo.get!(__MODULE__, id)
end

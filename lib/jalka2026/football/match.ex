defmodule Jalka2026.Football.Match do
  use Ecto.Schema
  import Ecto.Changeset

  alias Jalka2026.Football.{Competition, Team}
  alias Jalka2026.Repo

  @type t :: %__MODULE__{
          id: pos_integer() | nil,
          group: String.t() | nil,
          home_team_id: pos_integer() | nil,
          away_team_id: pos_integer() | nil,
          home_score: non_neg_integer() | nil,
          away_score: non_neg_integer() | nil,
          result: String.t() | nil,
          date: NaiveDateTime.t() | nil,
          finished: boolean()
        }

  schema "matches" do
    field(:group, :string)
    belongs_to(:home_team, Team)
    belongs_to(:away_team, Team)
    field(:home_score, :integer)
    field(:away_score, :integer)
    field(:result, :string)
    field(:date, :naive_datetime)
    field(:finished, :boolean, default: false)
    belongs_to(:competition, Competition, type: :string)

    timestamps()
  end

  @doc false
  def changeset(match, attrs) do
    match
    |> cast(attrs, [
      :group,
      :home_team_id,
      :away_team_id,
      :home_score,
      :away_score,
      :result,
      :date,
      :finished,
      :competition_id
    ])
    |> validate_inclusion(:group, Jalka2026.Football.match_groups())
  end

  def get_match!(id), do: Repo.get!(__MODULE__, id)

  @doc false
  def create_changeset(match, attrs) do
    match
    |> cast(attrs, [:home_score, :away_score, :finished, :result])
  end
end

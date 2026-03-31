defmodule Jalka2026.Football.Match do
  use Ecto.Schema
  import Ecto.Changeset

  alias Jalka2026.Football.{Team, Competition}
  alias Jalka2026.Repo

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

  @valid_groups [
    "Alagrupp A",
    "Alagrupp B",
    "Alagrupp C",
    "Alagrupp D",
    "Alagrupp E",
    "Alagrupp F",
    "Alagrupp G",
    "Alagrupp H",
    "Alagrupp I",
    "Alagrupp J",
    "Alagrupp K",
    "Alagrupp L"
  ]

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
    |> validate_inclusion(:group, @valid_groups)
  end

  def get_match!(id), do: Repo.get!(Match, id)

  @doc false
  def create_changeset(match, attrs) do
    match
    |> cast(attrs, [:home_score, :away_score, :finished, :result])
  end
end

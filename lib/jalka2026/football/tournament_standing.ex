defmodule Jalka2026.Football.TournamentStanding do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tournament_standings" do
    field(:tournament_id, :string)
    field(:tournament_name, :string)
    field(:position, :integer)
    field(:team_code, :string)
    field(:team_name, :string)

    timestamps()
  end

  @doc false
  def changeset(tournament_standing, attrs) do
    tournament_standing
    |> cast(attrs, [
      :tournament_id,
      :tournament_name,
      :position,
      :team_code,
      :team_name
    ])
    |> validate_required([
      :tournament_id,
      :tournament_name,
      :position,
      :team_code,
      :team_name
    ])
    |> validate_inclusion(:position, 1..4)
  end
end

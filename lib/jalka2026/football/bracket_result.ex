defmodule Jalka2026.Football.BracketResult do
  use Ecto.Schema
  import Ecto.Changeset

  alias Jalka2026.Football.{Team, Competition}

  @rounds ~w(round_of_32 round_of_16 quarter_final semi_final final winner)

  schema "bracket_results" do
    belongs_to(:team, Team)
    field(:round, :string)
    field(:position, :integer)
    belongs_to(:competition, Competition, type: :string)

    timestamps()
  end

  @doc false
  def changeset(bracket_result, attrs) do
    bracket_result
    |> cast(attrs, [:team_id, :round, :position, :competition_id])
    |> validate_required([:round, :position])
    |> validate_inclusion(:round, @rounds)
    |> unique_constraint([:round, :position])
    |> assoc_constraint(:team)
  end

  @doc "Get all valid rounds"
  def rounds, do: @rounds
end

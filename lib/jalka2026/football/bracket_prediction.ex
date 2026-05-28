defmodule Jalka2026.Football.BracketPrediction do
  use Ecto.Schema
  import Ecto.Changeset

  alias Jalka2026.Accounts.User
  alias Jalka2026.Football.Team

  @rounds ~w(round_of_32 round_of_16 quarter_final semi_final final)

  schema "bracket_predictions" do
    belongs_to(:user, User)
    belongs_to(:team, Team)
    field(:round, :string)
    field(:position, :integer)
    field(:side, :string)

    timestamps()
  end

  @doc false
  def changeset(bracket_prediction, attrs) do
    bracket_prediction
    |> cast(attrs, [:user_id, :team_id, :round, :position, :side])
    |> validate_required([:user_id, :round, :position])
    |> validate_inclusion(:round, @rounds)
    |> validate_inclusion(:side, ["a", "b"], message: "must be a or b")
    |> validate_position()
    |> unique_constraint([:user_id, :round, :position],
      name: :bracket_predictions_user_round_pos_winner_index
    )
    |> unique_constraint([:user_id, :round, :position, :side],
      name: :bracket_predictions_user_round_pos_side_index
    )
    |> assoc_constraint(:user)
    |> assoc_constraint(:team)
  end

  defp validate_position(changeset) do
    round = get_field(changeset, :round)
    position = get_field(changeset, :position)

    max_positions = %{
      "round_of_32" => 16,
      "round_of_16" => 8,
      "quarter_final" => 4,
      "semi_final" => 2,
      "final" => 1
    }

    if round && position do
      max = Map.get(max_positions, round, 0)

      if position >= 1 && position <= max do
        changeset
      else
        add_error(changeset, :position, "invalid position for round #{round}")
      end
    else
      changeset
    end
  end

  @doc "Get all valid rounds"
  def rounds, do: @rounds

  @doc "Get number of positions for a round"
  def positions_for_round(round) do
    case round do
      "round_of_32" -> 16
      "round_of_16" -> 8
      "quarter_final" -> 4
      "semi_final" -> 2
      "final" -> 1
      _ -> 0
    end
  end

  @doc "Get the next round after the given round"
  def next_round(round) do
    case round do
      "round_of_32" -> "round_of_16"
      "round_of_16" -> "quarter_final"
      "quarter_final" -> "semi_final"
      "semi_final" -> "final"
      "final" -> nil
      _ -> nil
    end
  end

  @doc "Get display name for round (in Estonian)"
  def round_display_name(round) do
    case round do
      "round_of_32" -> "32 parimat"
      "round_of_16" -> "Kaheksandikfinaal"
      "quarter_final" -> "Veerandfinaal"
      "semi_final" -> "Poolfinaal"
      "final" -> "Finaal"
      _ -> round
    end
  end
end

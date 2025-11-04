defmodule Jalka2026.Scoring.ScoringEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]
  schema "scoring_events" do
    field :match_id, :integer
    field :mode, :string
    field :affected_predictions_count, :integer
    field :latency_ms, :integer
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    timestamps()
  end

  @required ~w(match_id mode)a
  @optional ~w(affected_predictions_count latency_ms started_at completed_at)a

  def changeset(event, attrs) do
    event
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:mode, ["incremental", "full"])
    |> validate_number(:affected_predictions_count, greater_than_or_equal_to: 0)
    |> validate_number(:latency_ms, greater_than_or_equal_to: 0)
  end
end

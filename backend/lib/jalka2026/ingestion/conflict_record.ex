defmodule Jalka2026.Ingestion.ConflictRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]
  schema "conflict_records" do
    field :external_match_id, :string
    field :feed_score_home, :integer
    field :feed_score_away, :integer
    field :local_score_home, :integer
    field :local_score_away, :integer
    field :resolved_at, :utc_datetime
    field :resolution, :string
    timestamps()
  end

  @required ~w(external_match_id feed_score_home feed_score_away local_score_home local_score_away)a
  @optional ~w(resolved_at resolution)a

  def changeset(record, attrs) do
    record
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:resolution, ["approved", "rejected", nil])
    |> check_constraint(:resolution, name: :conflict_resolution_requires_timestamp, prefix: nil)
  end

  def resolve_changeset(record, attrs) do
    record
    |> cast(attrs, [:resolution])
    |> validate_inclusion(:resolution, ["approved", "rejected"])
    |> put_change(:resolved_at, DateTime.utc_now())
  end
end

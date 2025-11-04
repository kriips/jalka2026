defmodule Jalka2026.Ingestion.IngestionEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]
  schema "ingestion_events" do
    field :external_match_id, :string
    field :event_type, :string
    field :status, :string
    field :message, :string
    field :payload_hash, :string
    field :latency_ms, :integer
    timestamps()
  end

  @required ~w(external_match_id event_type status)a
  @optional ~w(message payload_hash latency_ms)a

  def changeset(event, attrs) do
    event
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:event_type, ["fetched", "parsed", "ingested", "error", "noop"])
    |> validate_inclusion(:status, ["success", "error", "noop"])
    |> validate_number(:latency_ms, greater_than_or_equal_to: 0)
    |> unique_constraint(:payload_hash, name: :ingestion_events_payload_hash_index)
  end
end

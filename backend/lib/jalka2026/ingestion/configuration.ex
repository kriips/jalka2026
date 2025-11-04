defmodule Jalka2026.Ingestion.Configuration do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]
  schema "feed_configuration" do
    field :feed_enabled, :boolean, default: false
    field :polling_interval_seconds, :integer, default: 120
    field :max_retries, :integer, default: 5
    field :degraded_mode, :boolean, default: false
    field :api_key, :string
    field :feed_url, :string
    timestamps()
  end

  @required ~w(feed_enabled polling_interval_seconds max_retries degraded_mode)a
  @optional ~w(api_key feed_url)a

  def changeset(config, attrs) do
    config
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_number(:polling_interval_seconds, greater_than_or_equal_to: 30)
    |> validate_number(:max_retries, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    |> validate_format(:feed_url, ~r/^https?:\/\//, message: "must start with http:// or https://")
  end
end

defmodule Jalka2026.Football.Competition do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}

  @valid_types ~w(world_cup euros)

  schema "competitions" do
    field(:name, :string)
    field(:short_name, :string)
    field(:type, :string)
    field(:year, :integer)
    field(:start_date, :date)
    field(:end_date, :date)
    field(:prediction_deadline, :utc_datetime)
    field(:is_active, :boolean, default: false)
    field(:config, :map, default: %{})

    has_many(:teams, Jalka2026.Football.Team)
    has_many(:matches, Jalka2026.Football.Match)

    timestamps()
  end

  @doc false
  def changeset(competition, attrs) do
    competition
    |> cast(attrs, [
      :id,
      :name,
      :short_name,
      :type,
      :year,
      :start_date,
      :end_date,
      :prediction_deadline,
      :is_active,
      :config
    ])
    |> validate_required([:id, :name, :short_name, :type, :year])
    |> validate_inclusion(:type, @valid_types)
    |> unique_constraint(:id)
  end
end

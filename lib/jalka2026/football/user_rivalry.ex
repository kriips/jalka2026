defmodule Jalka2026.Football.UserRivalry do
  use Ecto.Schema
  import Ecto.Changeset

  alias Jalka2026.Accounts.User

  schema "user_rivalries" do
    field(:status, :string, default: "active")
    field(:notifications_enabled, :boolean, default: true)

    belongs_to(:user, User)
    belongs_to(:rival, User)

    timestamps()
  end

  @doc false
  def changeset(rivalry, attrs) do
    rivalry
    |> cast(attrs, [:user_id, :rival_id, :status, :notifications_enabled])
    |> validate_required([:user_id, :rival_id])
    |> validate_inclusion(:status, ["active", "paused"])
    |> validate_not_self_rivalry()
    |> unique_constraint([:user_id, :rival_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:rival_id)
  end

  defp validate_not_self_rivalry(changeset) do
    user_id = get_field(changeset, :user_id)
    rival_id = get_field(changeset, :rival_id)

    if user_id && rival_id && user_id == rival_id do
      add_error(changeset, :rival_id, "cannot rival yourself")
    else
      changeset
    end
  end
end

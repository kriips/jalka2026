defmodule Jalka2026.Accounts.AllowedUser do
  use Ecto.Schema
  import Ecto.Changeset

  schema "allowed_users" do
    field(:name, :string)
    field(:competition_id, :string, default: "wc-2026")
    timestamps()
  end

  @doc false
  def changeset(allowed_user, attrs) do
    allowed_user
    |> cast(attrs, [:name, :competition_id])
    |> unique_constraint([:name, :competition_id])
  end
end

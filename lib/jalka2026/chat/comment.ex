defmodule Jalka2026.Chat.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  alias Jalka2026.Accounts.User
  alias Jalka2026.Football.Match

  schema "match_comments" do
    field :content, :string
    belongs_to :user, User
    belongs_to :match, Match

    timestamps()
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:content, :user_id, :match_id])
    |> validate_required([:content, :user_id, :match_id])
    |> validate_length(:content, min: 1, max: 500)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:match_id)
  end
end

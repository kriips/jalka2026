defmodule Jalka2026.Chat.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  alias Jalka2026.Accounts.User
  alias Jalka2026.Football.Match

  @type t :: %__MODULE__{
          id: pos_integer() | nil,
          content: String.t() | nil,
          user_id: pos_integer() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          match_id: pos_integer() | nil,
          match: Match.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "match_comments" do
    field(:content, :string)
    belongs_to(:user, User)
    belongs_to(:match, Match)

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

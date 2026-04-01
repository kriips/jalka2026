defmodule Jalka2026.Football.UserBadge do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
    id: pos_integer() | nil,
    user_id: pos_integer() | nil,
    badge_type: String.t() | nil,
    awarded_at: NaiveDateTime.t() | nil
  }

  schema "user_badges" do
    belongs_to(:user, Jalka2026.Accounts.User)
    field(:badge_type, :string)
    field(:awarded_at, :naive_datetime)

    timestamps()
  end

  @doc false
  def changeset(user_badge, attrs) do
    user_badge
    |> cast(attrs, [:user_id, :badge_type, :awarded_at])
    |> validate_required([:user_id, :badge_type, :awarded_at])
    |> validate_inclusion(:badge_type, badge_types())
    |> unique_constraint([:user_id, :badge_type])
  end

  @doc """
  Returns all valid badge types.
  """
  def badge_types do
    [
      "perfect_match",
      "prophet",
      "underdog_picker",
      "streak_master",
      "group_guru",
      "playoff_oracle",
      "first_blood"
    ]
  end

  @doc """
  Returns display info for a badge type (Estonian labels).
  """
  def badge_info("perfect_match"),
    do: %{name: "Täpne Lask", description: "Ennustas täpse skoori", icon: "🎯"}

  def badge_info("prophet"),
    do: %{name: "Prohvet", description: "10+ õiget tulemust", icon: "🔮"}

  def badge_info("underdog_picker"),
    do: %{name: "Üllataja", description: "Ennustas 3+ üllatust õigesti", icon: "⚡"}

  def badge_info("streak_master"),
    do: %{name: "Seeriameister", description: "5+ mängu järjest õigesti", icon: "🔥"}

  def badge_info("group_guru"),
    do: %{name: "Grupiguru", description: "Ühe grupi kõik tulemused õiged", icon: "🏆"}

  def badge_info("playoff_oracle"),
    do: %{name: "Playoffi Oraakel", description: "5+ playoffi ennustust õiged", icon: "🌟"}

  def badge_info("first_blood"),
    do: %{name: "Esimene Veri", description: "Esimene õige ennustus", icon: "💫"}

  def badge_info(_), do: %{name: "Tundmatu", description: "", icon: "❓"}
end

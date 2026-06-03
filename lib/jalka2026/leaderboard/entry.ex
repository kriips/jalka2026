defmodule Jalka2026.Leaderboard.Entry do
  @moduledoc """
  Opaque struct representing a single leaderboard row.

  Fields:
  - `user_id` — the user's database ID
  - `rank` — 1-based rank (ties share the same rank)
  - `name` — display name
  - `group_points` — points earned from group-stage predictions
  - `playoff_points` — points earned from playoff predictions
  - `current_streak` — current consecutive correct predictions
  - `longest_streak` — longest streak achieved
  - `total_points` — sum of group + playoff points
  """

  @enforce_keys [
    :user_id,
    :rank,
    :name,
    :group_points,
    :playoff_points,
    :current_streak,
    :longest_streak,
    :total_points
  ]
  defstruct @enforce_keys

  @opaque t :: %__MODULE__{
            user_id: pos_integer(),
            rank: pos_integer(),
            name: String.t(),
            group_points: non_neg_integer(),
            playoff_points: non_neg_integer(),
            current_streak: non_neg_integer(),
            longest_streak: non_neg_integer(),
            total_points: non_neg_integer()
          }

  @doc """
  Build an entry from a map of attributes (used during leaderboard calculation).
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      user_id: attrs.user_id,
      rank: attrs.rank,
      name: attrs.name,
      group_points: attrs.group_points,
      playoff_points: attrs.playoff_points,
      current_streak: attrs.current_streak,
      longest_streak: attrs.longest_streak,
      total_points: attrs.total_points
    }
  end
end

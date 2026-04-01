defmodule Jalka2026.Leaderboard.Entry do
  @moduledoc """
  Opaque struct representing a single leaderboard row.

  Fields:
  - `user_id` — the user's database ID
  - `rank` — 1-based rank (ties share the same rank)
  - `name` — display name
  - `group_points` — points earned from group-stage predictions
  - `playoff_points` — points earned from playoff predictions
  - `bonus_points` — streak bonus points
  - `current_streak` — current consecutive correct predictions
  - `longest_streak` — longest streak achieved
  - `total_points` — sum of group + playoff + bonus points
  """

  @enforce_keys [:user_id, :rank, :name, :group_points, :playoff_points,
                  :bonus_points, :current_streak, :longest_streak, :total_points]
  defstruct @enforce_keys

  @opaque t :: %__MODULE__{
    user_id: pos_integer(),
    rank: pos_integer(),
    name: String.t(),
    group_points: non_neg_integer(),
    playoff_points: non_neg_integer(),
    bonus_points: non_neg_integer(),
    current_streak: non_neg_integer(),
    longest_streak: non_neg_integer(),
    total_points: non_neg_integer()
  }

  @doc """
  Build an entry from individual values (used during leaderboard calculation).
  """
  @spec new(pos_integer(), pos_integer(), String.t(), non_neg_integer(), non_neg_integer(),
            non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()
  def new(user_id, rank, name, group_points, playoff_points, bonus_points,
          current_streak, longest_streak, total_points) do
    %__MODULE__{
      user_id: user_id,
      rank: rank,
      name: name,
      group_points: group_points,
      playoff_points: playoff_points,
      bonus_points: bonus_points,
      current_streak: current_streak,
      longest_streak: longest_streak,
      total_points: total_points
    }
  end
end

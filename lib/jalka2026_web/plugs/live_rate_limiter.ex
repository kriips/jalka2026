defmodule Jalka2026Web.LiveRateLimiter do
  @moduledoc """
  Rate limiting for LiveView events using Hammer.
  Used to prevent rapid-fire prediction updates and other LiveView abuse.
  """

  @doc """
  Check if a prediction update is allowed for the given user.
  Allows 60 prediction updates per 60 seconds per user.
  Each group match needs multiple clicks (increment/decrement), so 12 groups × 6 matches × ~4 clicks
  means users can realistically need 50+ clicks in a focused session.
  Returns :ok or {:error, :rate_limited}.
  """
  def check_prediction_rate(user_id) do
    key = "prediction:#{user_id}"

    case Hammer.check_rate(key, 60_000, 60) do
      {:allow, _count} -> :ok
      {:deny, _limit} -> {:error, :rate_limited}
    end
  end

  @doc """
  Check if a playoff prediction toggle is allowed for the given user.
  Allows 60 toggles per 60 seconds per user.
  The full bracket has 32 selections (R32:16 + R16:8 + QF:4 + SF:2 + F:1 + Winner:1),
  and users may change their mind and re-click, so 60 comfortably covers normal usage.
  Returns :ok or {:error, :rate_limited}.
  """
  def check_playoff_prediction_rate(user_id) do
    key = "playoff_prediction:#{user_id}"

    case Hammer.check_rate(key, 60_000, 60) do
      {:allow, _count} -> :ok
      {:deny, _limit} -> {:error, :rate_limited}
    end
  end

  @doc """
  Check if a chat message is allowed for the given user.
  Allows 10 messages per 60 seconds per user.
  Returns :ok or {:error, :rate_limited}.
  """
  def check_chat_rate(user_id) do
    key = "chat:#{user_id}"

    case Hammer.check_rate(key, 60_000, 10) do
      {:allow, _count} -> :ok
      {:deny, _limit} -> {:error, :rate_limited}
    end
  end
end

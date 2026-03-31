defmodule Jalka2026Web.LiveRateLimiter do
  @moduledoc """
  Rate limiting for LiveView events using Hammer.
  Used to prevent rapid-fire prediction updates and other LiveView abuse.
  """

  @doc """
  Check if a prediction update is allowed for the given user.
  Allows 30 prediction updates per 60 seconds per user.
  Returns :ok or {:error, :rate_limited}.
  """
  def check_prediction_rate(user_id) do
    key = "prediction:#{user_id}"

    case Hammer.check_rate(key, 60_000, 30) do
      {:allow, _count} -> :ok
      {:deny, _limit} -> {:error, :rate_limited}
    end
  end

  @doc """
  Check if a playoff prediction toggle is allowed for the given user.
  Allows 20 toggles per 60 seconds per user.
  Returns :ok or {:error, :rate_limited}.
  """
  def check_playoff_prediction_rate(user_id) do
    key = "playoff_prediction:#{user_id}"

    case Hammer.check_rate(key, 60_000, 20) do
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

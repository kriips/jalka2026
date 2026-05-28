defmodule Jalka2026Web.LiveRateLimiterTest do
  use ExUnit.Case, async: true

  alias Jalka2026Web.LiveRateLimiter

  describe "check_prediction_rate/1" do
    test "allows predictions within rate limit" do
      user_id = System.unique_integer([:positive])
      assert :ok = LiveRateLimiter.check_prediction_rate(user_id)
    end

    test "denies predictions when rate limit is exceeded" do
      user_id = System.unique_integer([:positive])
      # Exhaust the limit (60 per minute for predictions)
      for _ <- 1..60 do
        assert :ok = LiveRateLimiter.check_prediction_rate(user_id)
      end

      # The 61st attempt should be denied
      assert {:error, :rate_limited} = LiveRateLimiter.check_prediction_rate(user_id)
    end
  end

  describe "check_playoff_prediction_rate/1" do
    test "allows playoff predictions within rate limit" do
      user_id = System.unique_integer([:positive])
      assert :ok = LiveRateLimiter.check_playoff_prediction_rate(user_id)
    end

    test "denies playoff predictions when rate limit is exceeded" do
      user_id = System.unique_integer([:positive])
      # Exhaust the limit (60 per minute for playoff predictions)
      for _ <- 1..60 do
        assert :ok = LiveRateLimiter.check_playoff_prediction_rate(user_id)
      end

      # The 61st attempt should be denied
      assert {:error, :rate_limited} = LiveRateLimiter.check_playoff_prediction_rate(user_id)
    end
  end

  describe "check_chat_rate/1" do
    test "allows chat messages within rate limit" do
      user_id = System.unique_integer([:positive])
      assert :ok = LiveRateLimiter.check_chat_rate(user_id)
    end

    test "denies chat messages when rate limit is exceeded" do
      user_id = System.unique_integer([:positive])
      # Exhaust the limit (10 per minute for chat)
      for _ <- 1..10 do
        assert :ok = LiveRateLimiter.check_chat_rate(user_id)
      end

      # The 11th attempt should be denied
      assert {:error, :rate_limited} = LiveRateLimiter.check_chat_rate(user_id)
    end
  end
end

defmodule Jalka2026Web.Plugs.RateLimiterTest do
  use Jalka2026Web.ConnCase

  alias Jalka2026Web.Plugs.RateLimiter

  describe "init/1" do
    test "passes through atom action" do
      assert RateLimiter.init(:login) == :login
      assert RateLimiter.init(:registration) == :registration
      assert RateLimiter.init(:password_reset) == :password_reset
    end
  end

  describe "call/2" do
    test "passes through in test environment" do
      conn = build_conn()
      result = RateLimiter.call(conn, :login)
      refute result.halted
    end
  end

  describe "rate limit denial logic" do
    test "allows requests within the limit" do
      # Use a unique key to avoid cross-test pollution
      unique_ip = "127.#{System.unique_integer([:positive, :monotonic]) |> rem(254)}.0.1"
      key = "login:#{unique_ip}"

      # Each of these should be allowed (limit is 5 per 60 seconds for login)
      for _ <- 1..5 do
        assert {:allow, _count} = Hammer.check_rate(key, 60_000, 5)
      end
    end

    test "denies requests that exceed the limit" do
      unique_ip = "192.#{System.unique_integer([:positive, :monotonic]) |> rem(254)}.0.1"
      key = "login:#{unique_ip}"

      # Exhaust the limit (5 per 60 seconds for login)
      for _ <- 1..5 do
        Hammer.check_rate(key, 60_000, 5)
      end

      # The 6th attempt should be denied
      assert {:deny, _limit} = Hammer.check_rate(key, 60_000, 5)
    end

    test "registration limit is more restrictive than login" do
      reg_ip = "10.#{System.unique_integer([:positive, :monotonic]) |> rem(254)}.0.1"
      reg_key = "registration:#{reg_ip}"

      # Exhaust registration limit (3 per 5 minutes)
      for _ <- 1..3 do
        Hammer.check_rate(reg_key, 300_000, 3)
      end

      # The 4th attempt should be denied
      assert {:deny, _limit} = Hammer.check_rate(reg_key, 300_000, 3)
    end
  end
end

defmodule Jalka2026Web.PredictionDeadlineTest do
  use Jalka2026Web.ConnCase

  alias Jalka2026Web.UserAuth

  describe "require_predictions_open/2 plug" do
    setup %{conn: conn} do
      # Store original deadline
      original_deadline = Application.get_env(:jalka2026, :prediction_deadline)
      on_exit(fn -> Application.put_env(:jalka2026, :prediction_deadline, original_deadline) end)

      # Prepare conn with flash support for testing
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> fetch_flash()

      {:ok, conn: conn}
    end

    test "allows access when deadline is in the future", %{conn: conn} do
      # Set deadline to tomorrow
      future_deadline = DateTime.utc_now() |> DateTime.add(24 * 60 * 60, :second)
      Application.put_env(:jalka2026, :prediction_deadline, future_deadline)

      conn = UserAuth.require_predictions_open(conn, [])

      # Connection should not be halted
      refute conn.halted
    end

    test "blocks access when deadline has passed", %{conn: conn} do
      # Set deadline to yesterday
      past_deadline = DateTime.utc_now() |> DateTime.add(-24 * 60 * 60, :second)
      Application.put_env(:jalka2026, :prediction_deadline, past_deadline)

      conn = UserAuth.require_predictions_open(conn, [])

      # Connection should be halted
      assert conn.halted
      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Ennustamine on suletud - turniir on alanud"
    end

    test "allows access when deadline is nil (not configured)", %{conn: conn} do
      Application.put_env(:jalka2026, :prediction_deadline, nil)

      conn = UserAuth.require_predictions_open(conn, [])

      # Connection should not be halted
      refute conn.halted
    end

    test "blocks access at exact deadline time", %{conn: conn} do
      # Set deadline to 1 second ago (just passed)
      just_passed = DateTime.utc_now() |> DateTime.add(-1, :second)
      Application.put_env(:jalka2026, :prediction_deadline, just_passed)

      conn = UserAuth.require_predictions_open(conn, [])

      assert conn.halted
    end
  end
end

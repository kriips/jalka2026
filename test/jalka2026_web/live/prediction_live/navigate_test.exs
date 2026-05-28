defmodule Jalka2026Web.UserPredictionLive.NavigateTest do
  use Jalka2026Web.ConnCase

  import Phoenix.LiveViewTest

  setup do
    # Store original deadline and ensure predictions are open for test
    original_deadline = Application.get_env(:jalka2026, :prediction_deadline)

    future_deadline = DateTime.utc_now() |> DateTime.add(24 * 60 * 60, :second)
    Application.put_env(:jalka2026, :prediction_deadline, future_deadline)

    on_exit(fn -> Application.put_env(:jalka2026, :prediction_deadline, original_deadline) end)
    :ok
  end

  describe "PredictionLive.Navigate (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/register"}}} = live(conn, "/football/predict")
    end
  end

  describe "PredictionLive.Navigate (authenticated, predictions open)" do
    setup :register_and_log_in_user

    test "renders prediction navigation page", %{conn: conn} do
      {:ok, view, html} = live(conn, "/football/predict")

      assert html =~ "Ennusta"
      assert has_element?(view, "#page-title", "Ennusta")
    end

    test "shows group navigation links", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/football/predict")

      # Should show group letters A-L for navigation
      assert html =~ "Alagrupp" || html =~ "Playoff"
    end
  end

  describe "PredictionLive.Navigate (predictions closed)" do
    setup %{conn: conn} do
      past_deadline = DateTime.utc_now() |> DateTime.add(-24 * 60 * 60, :second)
      Application.put_env(:jalka2026, :prediction_deadline, past_deadline)

      user = Jalka2026.AccountsFixtures.user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "redirects when predictions are closed", %{conn: conn} do
      result = live(conn, "/football/predict")

      assert {:error, {:redirect, %{to: "/"}}} = result
    end
  end
end

defmodule Jalka2026Web.AdminLive.PredictionsTest do
  use Jalka2026Web.ConnCase

  import Phoenix.LiveViewTest

  alias Jalka2026.Football
  alias Jalka2026.Football.BracketPrediction

  describe "AdminLive.Predictions (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/register"}}} = live(conn, "/admin/predictions")
    end
  end

  describe "AdminLive.Predictions (non-admin user)" do
    setup :register_and_log_in_user

    test "redirects non-admin user away", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/admin/predictions")
    end
  end

  describe "AdminLive.Predictions (admin user)" do
    setup %{conn: conn} do
      user = Jalka2026.AccountsFixtures.user_fixture()

      user
      |> Ecto.Changeset.change(%{is_admin: true})
      |> Jalka2026.Repo.update!()

      admin_user = Jalka2026.Repo.get!(Jalka2026.Accounts.User, user.id)
      %{conn: log_in_user(conn, admin_user), user: admin_user}
    end

    test "a complete bracket counts as valid playoff predictions", %{conn: conn} do
      user = Jalka2026.AccountsFixtures.user_fixture()
      fill_bracket(user)

      {:ok, _view, html} = live(conn, "/admin/predictions")

      row = user_row(html, user.name)
      assert row =~ ~r/Playoff:\s*OK/
      refute row =~ "Puudu: F"
    end

    test "a partially filled bracket lists the missing winner picks per round", %{conn: conn} do
      user = Jalka2026.AccountsFixtures.user_fixture()
      # Only the round-of-32 winners are picked.
      fill_round(user, "round_of_32")

      {:ok, _view, html} = live(conn, "/admin/predictions")

      row = user_row(html, user.name)
      refute row =~ "F32:"
      assert row =~ "F16:0/8"
      assert row =~ "F8:0/4"
      assert row =~ "F4:0/2"
      assert row =~ "F2:0/1"
    end
  end

  # Picks a distinct winner for every position of every round (31 picks total).
  defp fill_bracket(user) do
    Enum.each(BracketPrediction.rounds(), &fill_round(user, &1))
  end

  defp fill_round(user, round) do
    Enum.each(1..BracketPrediction.positions_for_round(round), fn position ->
      team = Jalka2026.FootballFixtures.team_fixture()

      {:ok, _} =
        Football.set_bracket_prediction(%{
          user_id: user.id,
          round: round,
          position: position,
          team_id: team.id
        })
    end)
  end

  # The page lists every user; isolate the validation row for the given name.
  defp user_row(html, user_name) do
    html
    |> Floki.parse_document!()
    |> Floki.find(".validation-row")
    |> Enum.find(fn row -> Floki.text(row) =~ user_name end)
    |> then(fn row ->
      assert row, "expected a validation row for #{user_name}"
      Floki.text(row)
    end)
  end
end

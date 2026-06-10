defmodule Jalka2026Web.UserPredictionLive.PlayoffsTest do
  use Jalka2026Web.ConnCase

  import Phoenix.LiveViewTest
  import Jalka2026.FootballFixtures

  alias Jalka2026.Football
  alias Jalka2026.Repo

  setup %{conn: conn} do
    original_deadline = Application.get_env(:jalka2026, :prediction_deadline)
    Application.put_env(:jalka2026, :prediction_deadline, DateTime.add(DateTime.utc_now(), 3600))

    on_exit(fn ->
      Application.put_env(:jalka2026, :prediction_deadline, original_deadline)
    end)

    %{conn: conn, user: Jalka2026.AccountsFixtures.user_fixture()}
  end

  test "legacy users see Estonian reset instructions", %{conn: conn, user: user} do
    mark_legacy(user)
    assert Football.get_playoff_bracket_version(user.id) == "legacy_2026"
    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, "/football/predict/playoffs")
    html = render(view)

    assert html =~ "kasutab varasemat asetust"
    assert has_element?(view, "button", "Lähtesta ametlikule asetusele")
  end

  test "reset button clears playoff picks and switches to official seeding", %{
    conn: conn,
    user: user
  } do
    mark_legacy(user)
    conn = log_in_user(conn, user)
    team = team_fixture()

    {:ok, _prediction} =
      Football.set_bracket_prediction(%{
        user_id: user.id,
        round: "round_of_16",
        position: 1,
        team_id: team.id
      })

    Football.add_playoff_prediction(%{user_id: user.id, team_id: team.id, phase: 16})

    {:ok, view, _html} = live(conn, "/football/predict/playoffs")

    view
    |> element("button", "Lähtesta ametlikule asetusele")
    |> render_click()

    refute render(view) =~ "kasutab varasemat asetust"
    assert Football.get_playoff_bracket_version(user.id) == "official_2026"
    assert Football.get_bracket_predictions_by_user(user.id) == []
    assert Football.get_playoff_predictions_by_user(user.id) == []
  end

  defp mark_legacy(user) do
    user
    |> Ecto.Changeset.change(playoff_bracket_version: "legacy_2026")
    |> Repo.update!()
  end
end

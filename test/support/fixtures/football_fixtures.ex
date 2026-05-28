defmodule Jalka2026.FootballFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Jalka2026.Football` context.
  """

  alias Jalka2026.Football.{
    Competition,
    GroupPrediction,
    Match,
    PlayoffPrediction,
    PlayoffResult,
    Team
  }

  alias Jalka2026.Repo

  @doc """
  Ensures the default competition exists for tests.
  """
  def ensure_competition_exists do
    competition_id = Jalka2026.Competitions.current_id()

    case Repo.get(Competition, competition_id) do
      nil ->
        %Competition{}
        |> Competition.changeset(%{
          id: competition_id,
          name: "FIFA World Cup 2026",
          short_name: "MM 2026",
          type: "world_cup",
          year: 2026,
          is_active: true
        })
        |> Repo.insert!()

      competition ->
        competition
    end
  end

  @doc """
  Creates a team.
  """
  def team_fixture(attrs \\ %{}) do
    ensure_competition_exists()

    {:ok, team} =
      %Team{}
      |> Team.changeset(
        Enum.into(attrs, %{
          name: "Team #{System.unique_integer([:positive])}",
          code: "T#{System.unique_integer([:positive])}",
          flag: "flag.png",
          group: "A"
        })
      )
      |> Repo.insert()

    team
  end

  @doc """
  Creates a match.
  """
  def match_fixture(attrs \\ %{}) do
    home_team = attrs[:home_team] || team_fixture()
    away_team = attrs[:away_team] || team_fixture()

    {:ok, match} =
      %Match{}
      |> Match.changeset(
        Enum.into(attrs, %{
          group: "Alagrupp A",
          home_team_id: home_team.id,
          away_team_id: away_team.id,
          date: ~N[2026-06-15 18:00:00],
          finished: false
        })
      )
      |> Repo.insert()

    match |> Repo.preload([:home_team, :away_team])
  end

  @doc """
  Creates a finished match with a result.
  """
  def finished_match_fixture(attrs \\ %{}) do
    home_team = attrs[:home_team] || team_fixture()
    away_team = attrs[:away_team] || team_fixture()
    home_score = attrs[:home_score] || 2
    away_score = attrs[:away_score] || 1

    result =
      cond do
        home_score > away_score -> "home"
        home_score < away_score -> "away"
        true -> "draw"
      end

    {:ok, match} =
      %Match{}
      |> Match.changeset(
        Enum.into(attrs, %{
          group: "Alagrupp A",
          home_team_id: home_team.id,
          away_team_id: away_team.id,
          date: ~N[2026-06-15 18:00:00],
          home_score: home_score,
          away_score: away_score,
          result: result,
          finished: true
        })
      )
      |> Repo.insert()

    match |> Repo.preload([:home_team, :away_team])
  end

  @doc """
  Creates a group prediction.
  """
  def group_prediction_fixture(attrs \\ %{}) do
    user = attrs[:user] || Jalka2026.AccountsFixtures.user_fixture()
    match = attrs[:match] || match_fixture()
    home_score = attrs[:home_score] || 1
    away_score = attrs[:away_score] || 1

    result =
      cond do
        home_score > away_score -> "home"
        home_score < away_score -> "away"
        true -> "draw"
      end

    {:ok, prediction} =
      %GroupPrediction{}
      |> GroupPrediction.create_changeset(%{
        user_id: user.id,
        match_id: match.id,
        home_score: home_score,
        away_score: away_score,
        result: result
      })
      |> Repo.insert()

    prediction |> Repo.preload([:user, match: [:home_team, :away_team]])
  end

  @doc """
  Creates a playoff prediction.
  """
  def playoff_prediction_fixture(attrs \\ %{}) do
    user = attrs[:user] || Jalka2026.AccountsFixtures.user_fixture()
    team = attrs[:team] || team_fixture()

    {:ok, prediction} =
      %PlayoffPrediction{}
      |> PlayoffPrediction.create_changeset(%{
        user_id: user.id,
        team_id: team.id,
        phase: attrs[:phase] || 16
      })
      |> Repo.insert()

    prediction |> Repo.preload([:user, :team])
  end

  @doc """
  Creates a playoff result.
  """
  def playoff_result_fixture(attrs \\ %{}) do
    ensure_competition_exists()
    team = attrs[:team] || team_fixture()

    {:ok, result} =
      %PlayoffResult{}
      |> PlayoffResult.create_changeset(%{
        team_id: team.id,
        phase: attrs[:phase] || 16,
        competition_id: Jalka2026.Competitions.current_id()
      })
      |> Repo.insert()

    result |> Repo.preload([:team])
  end
end

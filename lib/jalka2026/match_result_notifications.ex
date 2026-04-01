defmodule Jalka2026.MatchResultNotifications do
  @moduledoc """
  Handles sending email notifications to users when match results are entered.

  This module coordinates gathering user predictions, calculating points earned,
  determining leaderboard positions, and dispatching emails asynchronously.
  """

  require Logger

  alias Jalka2026.Football
  alias Jalka2026.Accounts
  alias Jalka2026.Accounts.UserNotifier
  alias Jalka2026.Leaderboard
  alias Jalka2026.Scoring
  alias Jalka2026Web.Resolvers.FootballResolver

  @doc """
  Sends match result notifications to all users who made predictions for the given match.

  This function is called after a match result is entered and the leaderboard is recalculated.
  It runs asynchronously to avoid blocking the admin interface.

  ## Parameters
  - `match_id`: The ID of the match that was just scored
  - `leaderboard_changes`: Map of user_id => %{rank_change: change, points_change: change}

  ## Returns
  - `{:ok, count}` where count is the number of notifications sent
  """
  def send_notifications(match_id, leaderboard_changes \\ %{}) do
    parent = self()
    Task.start(fn ->
      try do
        Ecto.Adapters.SQL.Sandbox.allow(Jalka2026.Repo, parent, self())
        send_notifications_sync(match_id, leaderboard_changes)
      rescue
        _ -> :ok
      catch
        :exit, _ -> :ok
      end
    end)

    {:ok, :notifications_queued}
  end

  @doc """
  Synchronous version of send_notifications for testing purposes.
  """
  def send_notifications_sync(match_id, leaderboard_changes \\ %{}) do
    match = Football.get_match(match_id)

    if match && match.finished do
      leaderboard = Leaderboard.get_leaderboard()
      users = Accounts.list_users()

      results =
        users
        |> Enum.map(fn user ->
          send_notification_to_user(user, match, leaderboard, leaderboard_changes)
        end)

      sent_count = Enum.count(results, fn result -> match?({{:ok, _}, _}, result) end)
      skipped_count = Enum.count(results, fn result -> match?({{:ok, :skipped_no_email}, _}, result) end)
      error_count = Enum.count(results, fn result -> match?({{:error, _}, _}, result) end)

      Logger.info(
        "Match result notifications for match #{match_id}: " <>
          "#{sent_count} sent, #{skipped_count} skipped (no email), #{error_count} errors"
      )

      {:ok, %{sent: sent_count, skipped: skipped_count, errors: error_count}}
    else
      Logger.warning("Match #{match_id} not found or not finished, skipping notifications")
      {:error, :match_not_found_or_not_finished}
    end
  end

  defp send_notification_to_user(user, match, leaderboard, leaderboard_changes) do
    prediction = Football.get_prediction_by_user_match(user.id, match.id)
    points_earned = calculate_points_for_match(match, prediction)
    leaderboard_position = get_user_leaderboard_position(user.id, leaderboard, leaderboard_changes)

    result = UserNotifier.deliver_match_result_notification(
      user,
      match,
      prediction,
      points_earned,
      leaderboard_position
    )

    {result, user.id}
  end

  defp calculate_points_for_match(match, prediction) do
    Scoring.group_match_points(match, prediction)
  end

  defp get_user_leaderboard_position(user_id, leaderboard, leaderboard_changes) do
    alias Jalka2026.Leaderboard.Entry

    user_entry = Enum.find(leaderboard, fn %Entry{user_id: uid} -> uid == user_id end)

    case user_entry do
      %Entry{rank: rank, total_points: total_points} ->
        rank_change = case Map.get(leaderboard_changes, user_id) do
          nil -> nil
          %{rank_change: :new} -> nil
          %{rank_change: change} -> change
        end

        %{
          rank: rank,
          total_points: total_points,
          rank_change: rank_change
        }

      nil ->
        nil
    end
  end

  @doc """
  Sends playoff result notifications to all users.

  Similar to match notifications but for playoff phase results.

  ## Parameters
  - `phase`: The playoff phase (32, 16, 8, 4, 2, 1)
  - `team_id`: The team that advanced
  - `leaderboard_changes`: Map of changes from leaderboard recalculation
  """
  def send_playoff_notifications(phase, team_id, leaderboard_changes \\ %{}) do
    parent = self()
    Task.start(fn ->
      try do
        Ecto.Adapters.SQL.Sandbox.allow(Jalka2026.Repo, parent, self())
        send_playoff_notifications_sync(phase, team_id, leaderboard_changes)
      rescue
        _ -> :ok
      catch
        :exit, _ -> :ok
      end
    end)

    {:ok, :notifications_queued}
  end

  @doc """
  Synchronous version for testing.
  """
  def send_playoff_notifications_sync(phase, team_id, leaderboard_changes \\ %{}) do
    team = Football.get_team(team_id)
    leaderboard = Leaderboard.get_leaderboard()
    users = Accounts.list_users()

    phase_names = %{
      32 => "32 parimat",
      16 => "Kaheksandikfinaalid",
      8 => "Veerandfinaalid",
      4 => "Poolfinaalid",
      2 => "Finaal",
      1 => "Võitja"
    }

    phase_points = Scoring.playoff_phase_points_map()

    results =
      users
      |> Enum.map(fn user ->
        send_playoff_notification_to_user(
          user,
          team,
          phase,
          phase_names[phase],
          phase_points[phase],
          leaderboard,
          leaderboard_changes
        )
      end)

    sent_count = Enum.count(results, fn result -> match?({{:ok, _}, _}, result) end)

    Logger.info(
      "Playoff result notifications for phase #{phase}: #{sent_count} sent"
    )

    {:ok, %{sent: sent_count}}
  end

  defp send_playoff_notification_to_user(user, team, phase, phase_name, phase_points, leaderboard, leaderboard_changes) do
    # Check if user predicted this team for this phase
    user_playoff_predictions = FootballResolver.get_playoff_predictions(user.id)
    predicted_teams = Map.get(user_playoff_predictions, phase, [])
    user_predicted = Enum.member?(predicted_teams, team.id)

    points_earned = if user_predicted, do: phase_points, else: 0
    leaderboard_position = get_user_leaderboard_position(user.id, leaderboard, leaderboard_changes)

    result = deliver_playoff_notification(
      user,
      team,
      phase_name,
      user_predicted,
      points_earned,
      leaderboard_position
    )

    {result, user.id}
  end

  defp deliver_playoff_notification(user, team, phase_name, user_predicted, points_earned, leaderboard_position) do
    if user.email && user.email != "" do
      alias Jalka2026.Football.TeamTranslations
      team_name = TeamTranslations.translate(team.name)

      subject = "Playoff tulemus: #{team_name} - Jalka2026"

      prediction_text = if user_predicted do
        "Sa ennustasid, et #{team_name} jõuab sellesse vooru - tubli!"
      else
        "Sa ei ennustanud, et #{team_name} jõuab sellesse vooru."
      end

      points_text = if points_earned > 0 do
        "Teenisid #{points_earned} punkti!"
      else
        "Punkte ei teenitud selle tulemuse eest."
      end

      position_text = case leaderboard_position do
        %{rank: rank, total_points: total_points} ->
          "Sinu koht edetabelis: #{rank}. koht\nKokku punkte: #{total_points}"
        _ -> ""
      end

      body = """

      ==============================

      Tere #{user.name}!

      Playoff tulemus: #{phase_name}

      #{team_name} on edasi jõudnud!

      #{prediction_text}

      #{points_text}

      #{position_text}

      Vaata edetabelit: https://jalka.eys.ee/leaderboard

      ==============================
      """

      {from_name, from_email} = Application.get_env(:jalka2026, :email_from, {"Jalka2026", "noreply@jalka.eys.ee"})

      email =
        Bamboo.Email.new_email()
        |> Bamboo.Email.to(user.email)
        |> Bamboo.Email.from({from_name, from_email})
        |> Bamboo.Email.subject(subject)
        |> Bamboo.Email.text_body(body)

      if Application.get_env(:jalka2026, :environment) == :dev do
        Logger.info("Email to #{user.email}:\nSubject: #{subject}\n#{body}")
        {:ok, email}
      else
        case Jalka2026.Mailer.deliver_now(email) do
          {:ok, _} = result -> result
          {:error, _} = error -> error
          email -> {:ok, email}
        end
      end
    else
      {:ok, :skipped_no_email}
    end
  end
end

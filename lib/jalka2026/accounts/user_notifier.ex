defmodule Jalka2026.Accounts.UserNotifier do
  @moduledoc """
  Handles email notifications for users.

  Uses Bamboo for email delivery. In development, emails are logged.
  In production, emails are sent via SMTP.
  """

  import Bamboo.Email

  alias Jalka2026.Football.TeamTranslations
  alias Jalka2026.Mailer

  defp deliver(to, subject, body) do
    {from_name, from_email} =
      Application.get_env(:jalka2026, :email_from, {"Jalka2026", "noreply@jalka.eys.ee"})

    email =
      new_email()
      |> to(to)
      |> from({from_name, from_email})
      |> subject(subject)
      |> text_body(body)

    # In development, just log the email
    if Application.get_env(:jalka2026, :environment) == :dev do
      require Logger
      Logger.info("Email to #{to}:\nSubject: #{subject}\n#{body}")
      {:ok, email}
    else
      case Mailer.deliver_now(email) do
        {:ok, _} = result -> result
        {:error, _} = error -> error
        email -> {:ok, email}
      end
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Kinnita oma konto - Jalka2026", """

    ==============================

    Tere #{user.email},

    oma konto kinnitamiseks vajuta allolevale lingile:

    #{url}

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Parooli lähtestamine - Jalka2026", """

    ==============================

    Tere #{user.email},

    parooli lähtestamiseks mine allolevale lingile:

    #{url}

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Meiliaadressi muutmine - Jalka2026", """

    ==============================

    Tere #{user.email},

    oma meiliaadressi vahetamiseks mine allolevale lingile:

    #{url}

    ==============================
    """)
  end

  @doc """
  Deliver match result notification to a user.

  Includes information about:
  - The match result
  - User's prediction
  - Points earned
  - Updated leaderboard position
  """
  def deliver_match_result_notification(
        user,
        match,
        prediction,
        points_earned,
        leaderboard_position
      ) do
    # Skip users without email
    if user.email && user.email != "" do
      home_team = TeamTranslations.translate(match.home_team.name)
      away_team = TeamTranslations.translate(match.away_team.name)

      subject = "Mängu tulemus: #{home_team} vs #{away_team} - Jalka2026"

      body =
        build_match_result_body(
          user,
          match,
          prediction,
          points_earned,
          leaderboard_position,
          home_team,
          away_team
        )

      deliver(user.email, subject, body)
    else
      {:ok, :skipped_no_email}
    end
  end

  defp build_match_result_body(
         user,
         match,
         prediction,
         points_earned,
         leaderboard_position,
         home_team,
         away_team
       ) do
    prediction_text = format_prediction(prediction, home_team, away_team)
    points_text = format_points(points_earned, prediction, match)
    position_text = format_position(leaderboard_position)

    """

    ==============================

    Tere #{user.name}!

    Mäng on lõppenud!

    #{home_team} #{match.home_score} - #{match.away_score} #{away_team}

    #{prediction_text}

    #{points_text}

    #{position_text}

    Vaata edetabelit: https://jalka.eys.ee/leaderboard

    ==============================
    """
  end

  defp format_prediction(nil, _home_team, _away_team) do
    "Sa ei teinud selle mängu kohta ennustust."
  end

  defp format_prediction(prediction, home_team, away_team) do
    "Sinu ennustus: #{home_team} #{prediction.home_score} - #{prediction.away_score} #{away_team}"
  end

  defp format_points(0, nil, _match) do
    "Punkte ei teenitud (ennustus puudus)."
  end

  defp format_points(0, prediction, match) when not is_nil(prediction) do
    if prediction.result != match.result do
      "Punkte ei teenitud (vale tulemus)."
    else
      "Punkte ei teenitud."
    end
  end

  defp format_points(1, _prediction, _match) do
    "Teenisid 1 punkti! (Oige tulemus)"
  end

  defp format_points(2, _prediction, _match) do
    "Suurepärane! Teenisid 2 punkti! (Täpne skoor)"
  end

  defp format_points(points, _prediction, _match) do
    "Teenisid #{points} punkti!"
  end

  defp format_position(%{rank: rank, total_points: total_points, rank_change: rank_change}) do
    change_text =
      case rank_change do
        nil -> ""
        0 -> " (koht ei muutunud)"
        change when change > 0 -> " (tõusid #{change} kohta!)"
        change -> " (langesid #{abs(change)} kohta)"
      end

    "Sinu koht edetabelis: #{rank}. koht#{change_text}\nKokku punkte: #{total_points}"
  end

  defp format_position(_), do: ""
end

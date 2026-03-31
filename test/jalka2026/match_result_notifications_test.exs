defmodule Jalka2026.MatchResultNotificationsTest do
  use Jalka2026.DataCase, async: false

  alias Jalka2026.MatchResultNotifications
  alias Jalka2026.Accounts.UserNotifier
  alias Jalka2026.Football

  import Jalka2026.AccountsFixtures
  import Jalka2026.FootballFixtures

  describe "send_notifications/2" do
    test "returns queued status immediately" do
      assert {:ok, :notifications_queued} = MatchResultNotifications.send_notifications(1, %{})
    end

    test "asynchronously queues notifications and returns immediately" do
      # The function should return immediately without waiting for the task
      # Verify it returns the expected tuple and doesn't block
      start = System.monotonic_time(:millisecond)
      assert {:ok, :notifications_queued} = MatchResultNotifications.send_notifications(999, %{})
      elapsed = System.monotonic_time(:millisecond) - start
      # Should return immediately, not wait for DB queries
      assert elapsed < 100, "send_notifications should return immediately (got #{elapsed}ms)"
    end
  end

  describe "send_notifications_sync/2" do
    test "returns error when match not found" do
      assert {:error, :match_not_found_or_not_finished} =
               MatchResultNotifications.send_notifications_sync(999_999, %{})
    end

    test "returns success with count breakdown when match exists with predictions" do
      user = user_fixture()

      match = match_fixture()
      Football.update_match_score(match.id, 2, 1)

      Football.change_score(%{
        user_id: user.id,
        match_id: match.id,
        home_score: 2,
        away_score: 1,
        result: "home"
      })

      result = MatchResultNotifications.send_notifications_sync(match.id, %{})

      assert {:ok, %{sent: sent, skipped: _skipped, errors: errors}} = result
      # sent is the total count of users processed (includes skipped_no_email)
      # At minimum, the user we created was processed
      assert sent >= 1, "Expected at least 1 notification to be processed"
      assert errors == 0, "Expected 0 errors"
    end

    test "sends a notification email to the specific user with prediction and email" do
      user = user_fixture()

      match = match_fixture()
      Football.update_match_score(match.id, 2, 1)

      Football.change_score(%{
        user_id: user.id,
        match_id: match.id,
        home_score: 2,
        away_score: 1,
        result: "home"
      })

      # Clear any previously sent emails before our test
      Bamboo.SentEmail.reset()

      MatchResultNotifications.send_notifications_sync(match.id, %{})

      # Verify the specific user received a notification
      sent_emails = Bamboo.SentEmail.all()
      user_email = Enum.find(sent_emails, fn email ->
        email.to == [nil: user.email]
      end)
      assert user_email != nil, "Expected notification email to be sent to #{user.email}"
    end

    test "does not return error when match has no predictions" do
      match = match_fixture()
      Football.update_match_score(match.id, 1, 0)

      result = MatchResultNotifications.send_notifications_sync(match.id, %{})
      assert {:ok, %{errors: 0}} = result
    end
  end

  describe "deliver_match_result_notification/5" do
    test "skips users without email" do
      user = %{
        id: 1,
        email: nil,
        name: "Test User"
      }

      match = %{
        home_team: %{name: "GER"},
        away_team: %{name: "FRA"},
        home_score: 2,
        away_score: 1
      }

      assert {:ok, :skipped_no_email} =
               UserNotifier.deliver_match_result_notification(
                 user,
                 match,
                 nil,
                 0,
                 %{rank: 1, total_points: 10, rank_change: 0}
               )
    end

    test "skips users with empty email" do
      user = %{
        id: 1,
        email: "",
        name: "Test User"
      }

      match = %{
        home_team: %{name: "GER"},
        away_team: %{name: "FRA"},
        home_score: 2,
        away_score: 1
      }

      assert {:ok, :skipped_no_email} =
               UserNotifier.deliver_match_result_notification(
                 user,
                 match,
                 nil,
                 0,
                 %{rank: 1, total_points: 10, rank_change: 0}
               )
    end

    test "sends notification to user with email" do
      user = %{
        id: 1,
        email: "test@example.com",
        name: "Test User"
      }

      match = %{
        home_team: %{name: "GER"},
        away_team: %{name: "FRA"},
        home_score: 2,
        away_score: 1
      }

      prediction = %{
        home_score: 2,
        away_score: 1,
        result: "home"
      }

      result =
        UserNotifier.deliver_match_result_notification(
          user,
          match,
          prediction,
          2,
          %{rank: 1, total_points: 10, rank_change: 2}
        )

      assert {:ok, email} = result
      # Bamboo stores email as [nil: "email@example.com"] format
      assert email.to == [nil: "test@example.com"]
      # The subject contains team names (translations or codes)
      assert email.subject =~ "GER" or email.subject =~ "Saksamaa"
      assert email.subject =~ "FRA" or email.subject =~ "Prantsusmaa"
      assert email.text_body =~ "Suurepärane! Teenisid 2 punkti!"
      assert email.text_body =~ "tõusid 2 kohta!"
    end

    test "formats points correctly for exact score match" do
      user = %{id: 1, email: "test@example.com", name: "Test"}
      match = %{home_team: %{name: "GER"}, away_team: %{name: "FRA"}, home_score: 2, away_score: 1}
      prediction = %{home_score: 2, away_score: 1, result: "home"}

      {:ok, email} = UserNotifier.deliver_match_result_notification(user, match, prediction, 2, nil)
      assert email.text_body =~ "Suurepärane! Teenisid 2 punkti! (Täpne skoor)"
    end

    test "formats points correctly for correct result only" do
      user = %{id: 1, email: "test@example.com", name: "Test"}
      match = %{home_team: %{name: "GER"}, away_team: %{name: "FRA"}, home_score: 2, away_score: 1, result: "home"}
      prediction = %{home_score: 3, away_score: 1, result: "home"}

      {:ok, email} = UserNotifier.deliver_match_result_notification(user, match, prediction, 1, nil)
      assert email.text_body =~ "Teenisid 1 punkti! (Oige tulemus)"
    end

    test "formats points correctly for wrong result" do
      user = %{id: 1, email: "test@example.com", name: "Test"}
      match = %{home_team: %{name: "GER"}, away_team: %{name: "FRA"}, home_score: 2, away_score: 1, result: "home"}
      prediction = %{home_score: 0, away_score: 2, result: "away"}

      {:ok, email} = UserNotifier.deliver_match_result_notification(user, match, prediction, 0, nil)
      assert email.text_body =~ "Punkte ei teenitud (vale tulemus)"
    end

    test "formats points correctly for missing prediction" do
      user = %{id: 1, email: "test@example.com", name: "Test"}
      match = %{home_team: %{name: "GER"}, away_team: %{name: "FRA"}, home_score: 2, away_score: 1}

      {:ok, email} = UserNotifier.deliver_match_result_notification(user, match, nil, 0, nil)
      assert email.text_body =~ "Sa ei teinud selle mängu kohta ennustust"
      assert email.text_body =~ "Punkte ei teenitud (ennustus puudus)"
    end
  end
end

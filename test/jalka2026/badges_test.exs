defmodule Jalka2026.BadgesTest do
  use Jalka2026.DataCase

  alias Jalka2026.Badges
  import Jalka2026.AccountsFixtures
  import Jalka2026.FootballFixtures

  describe "get_user_badges/1" do
    test "returns empty list for user with no badges" do
      user = user_fixture()
      assert Badges.get_user_badges(user.id) == []
    end
  end

  describe "get_badges_for_users/1" do
    test "returns empty map for users with no badges" do
      user = user_fixture()
      result = Badges.get_badges_for_users([user.id])
      assert result == %{}
    end
  end

  describe "recalculate_user_badges/3" do
    test "awards first_blood badge for one correct prediction" do
      user = user_fixture()
      match = finished_match_fixture(%{home_score: 2, away_score: 1})

      # Create a prediction that matches the result
      group_prediction_fixture(%{
        user: user,
        match: match,
        home_score: 3,
        away_score: 0  # Different score but same result (home wins)
      })

      Badges.recalculate_user_badges(user.id, [match], [])

      badges = Badges.get_user_badges(user.id)
      badge_types = Enum.map(badges, & &1.badge_type)
      assert "first_blood" in badge_types
    end

    test "awards perfect_match badge for exact score prediction" do
      user = user_fixture()
      match = finished_match_fixture(%{home_score: 2, away_score: 1})

      # Create a prediction with exact score match
      group_prediction_fixture(%{
        user: user,
        match: match,
        home_score: 2,
        away_score: 1
      })

      Badges.recalculate_user_badges(user.id, [match], [])

      badges = Badges.get_user_badges(user.id)
      badge_types = Enum.map(badges, & &1.badge_type)
      assert "perfect_match" in badge_types
      assert "first_blood" in badge_types
    end

    test "does not award badges for wrong predictions" do
      user = user_fixture()
      match = finished_match_fixture(%{home_score: 2, away_score: 1})

      # Create a prediction that doesn't match
      group_prediction_fixture(%{
        user: user,
        match: match,
        home_score: 0,
        away_score: 3  # Wrong result
      })

      Badges.recalculate_user_badges(user.id, [match], [])

      badges = Badges.get_user_badges(user.id)
      assert badges == []
    end

    test "does not duplicate badges on recalculation" do
      user = user_fixture()
      match = finished_match_fixture(%{home_score: 2, away_score: 1})

      group_prediction_fixture(%{
        user: user,
        match: match,
        home_score: 2,
        away_score: 1
      })

      # Run twice
      Badges.recalculate_user_badges(user.id, [match], [])
      Badges.recalculate_user_badges(user.id, [match], [])

      badges = Badges.get_user_badges(user.id)
      badge_types = Enum.map(badges, & &1.badge_type)
      # Each badge type should only appear once
      assert length(Enum.filter(badge_types, &(&1 == "perfect_match"))) == 1
    end
  end
end

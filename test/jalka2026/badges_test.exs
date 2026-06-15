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
        # Different score but same result (home wins)
        away_score: 0
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
        # Wrong result
        away_score: 3
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

    test "awards sniper for 5+ exact scores" do
      user = user_fixture()

      matches =
        for _ <- 1..5 do
          match = finished_match_fixture(%{home_score: 2, away_score: 1})
          group_prediction_fixture(%{user: user, match: match, home_score: 2, away_score: 1})
          match
        end

      Badges.recalculate_user_badges(user.id, matches, [])

      assert "sniper" in badge_types(user)
    end

    test "awards cold_blood for a 10-game streak" do
      user = user_fixture()

      matches =
        for _ <- 1..10 do
          match = finished_match_fixture(%{home_score: 2, away_score: 1})
          # Correct result, different score
          group_prediction_fixture(%{user: user, match: match, home_score: 3, away_score: 0})
          match
        end

      Badges.recalculate_user_badges(user.id, matches, [])

      types = badge_types(user)
      assert "cold_blood" in types
      assert "streak_master" in types
    end

    test "awards draw_master for 3+ correct draws" do
      user = user_fixture()

      matches =
        for _ <- 1..3 do
          match = finished_match_fixture(%{home_score: 1, away_score: 1})
          group_prediction_fixture(%{user: user, match: match, home_score: 2, away_score: 2})
          match
        end

      Badges.recalculate_user_badges(user.id, matches, [])

      assert "draw_master" in badge_types(user)
    end

    test "awards goal_machine for an exact high-scoring prediction" do
      user = user_fixture()
      # 5 total goals
      match = finished_match_fixture(%{home_score: 3, away_score: 2})
      group_prediction_fixture(%{user: user, match: match, home_score: 3, away_score: 2})

      Badges.recalculate_user_badges(user.id, [match], [])

      assert "goal_machine" in badge_types(user)
    end

    test "does not award goal_machine for an exact low-scoring prediction" do
      user = user_fixture()
      # 1 total goal
      match = finished_match_fixture(%{home_score: 1, away_score: 0})
      group_prediction_fixture(%{user: user, match: match, home_score: 1, away_score: 0})

      Badges.recalculate_user_badges(user.id, [match], [])

      types = badge_types(user)
      assert "perfect_match" in types
      refute "goal_machine" in types
    end

    test "awards bracket_master when all four semifinalists are correct" do
      user = user_fixture()

      results =
        for _ <- 1..4 do
          team = team_fixture()
          playoff_prediction_fixture(%{user: user, team: team, phase: 8})
          playoff_result_fixture(%{team: team, phase: 8})
        end

      Badges.recalculate_user_badges(user.id, [], results)

      assert "bracket_master" in badge_types(user)
    end

    test "does not award bracket_master when a semifinalist is wrong" do
      user = user_fixture()

      # Predict three correct semifinalists and one wrong one
      results =
        for _ <- 1..3 do
          team = team_fixture()
          playoff_prediction_fixture(%{user: user, team: team, phase: 8})
          playoff_result_fixture(%{team: team, phase: 8})
        end

      playoff_prediction_fixture(%{user: user, team: team_fixture(), phase: 8})
      # Fourth actual semifinalist the user did not predict
      results = [playoff_result_fixture(%{team: team_fixture(), phase: 8}) | results]

      Badges.recalculate_user_badges(user.id, [], results)

      refute "bracket_master" in badge_types(user)
    end
  end

  describe "underdog badges" do
    test "awards underdog_picker and chaos_master for minority correct picks" do
      target = user_fixture()
      # Four other users so each minority pick is 1-in-5 (20% < 25%)
      others = for _ <- 1..4, do: user_fixture()

      matches =
        for _ <- 1..6 do
          # Away win — the unpopular outcome
          match = finished_match_fixture(%{home_score: 0, away_score: 1})
          group_prediction_fixture(%{user: target, match: match, home_score: 0, away_score: 2})

          for other <- others do
            group_prediction_fixture(%{user: other, match: match, home_score: 2, away_score: 0})
          end

          match
        end

      Badges.recalculate_user_badges(target.id, matches, [])

      types = badge_types(target)
      assert "underdog_picker" in types
      assert "chaos_master" in types
    end

    test "does not award underdog for a majority correct pick" do
      target = user_fixture()
      others = for _ <- 1..3, do: user_fixture()

      # Home win that everyone, including the target, predicted (100% agreement)
      match = finished_match_fixture(%{home_score: 2, away_score: 0})
      group_prediction_fixture(%{user: target, match: match, home_score: 2, away_score: 0})

      for other <- others do
        group_prediction_fixture(%{user: other, match: match, home_score: 1, away_score: 0})
      end

      Badges.recalculate_user_badges(target.id, [match], [])

      types = badge_types(target)
      assert "first_blood" in types
      refute "underdog_picker" in types
    end
  end

  describe "award_rank_badges/2" do
    test "awards leader to a ranked-first user with points and climber on a 5+ rank gain" do
      user = user_fixture()
      new_lb = [%{user_id: user.id, rank: 1, total_points: 40}]
      old_lb = [%{user_id: user.id, rank: 6, total_points: 5}]

      Badges.award_rank_badges(new_lb, old_lb)

      types = badge_types(user)
      assert "leader" in types
      assert "climber" in types
    end

    test "does not award leader at rank 1 with zero points" do
      user = user_fixture()
      new_lb = [%{user_id: user.id, rank: 1, total_points: 0}]

      Badges.award_rank_badges(new_lb, [])

      refute "leader" in badge_types(user)
    end

    test "does not award climber for a small or negative rank change" do
      user = user_fixture()
      new_lb = [%{user_id: user.id, rank: 3, total_points: 20}]
      old_lb = [%{user_id: user.id, rank: 5, total_points: 18}]

      Badges.award_rank_badges(new_lb, old_lb)

      refute "climber" in badge_types(user)
    end
  end

  defp badge_types(user) do
    user.id
    |> Badges.get_user_badges()
    |> Enum.map(& &1.badge_type)
  end
end

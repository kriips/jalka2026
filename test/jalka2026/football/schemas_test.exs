defmodule Jalka2026.Football.SchemasTest do
  use Jalka2026.DataCase

  import Jalka2026.FootballFixtures
  import Jalka2026.AccountsFixtures

  alias Jalka2026.Football.{
    Match,
    Team,
    GroupPrediction,
    PlayoffPrediction,
    PlayoffResult,
    Competition,
    HistoricalMatch,
    TournamentStanding,
    BracketPrediction,
    BracketResult,
    UserBadge,
    UserFavoriteTeam,
    UserRivalry,
    UserStreak
  }

  describe "Match" do
    test "changeset with valid attributes" do
      team1 = team_fixture()
      team2 = team_fixture()

      changeset =
        Match.changeset(%Match{}, %{
          group: "Alagrupp A",
          home_team_id: team1.id,
          away_team_id: team2.id,
          date: ~N[2026-06-15 18:00:00],
          finished: false
        })

      assert changeset.valid?
    end

    test "changeset validates group inclusion" do
      changeset = Match.changeset(%Match{}, %{group: "Invalid Group"})
      assert %{group: ["is invalid"]} = errors_on(changeset)
    end

    test "create_changeset casts score fields" do
      changeset =
        Match.create_changeset(%Match{}, %{
          home_score: 2,
          away_score: 1,
          finished: true,
          result: "home"
        })

      assert changeset.valid?
    end
  end

  describe "Team" do
    test "changeset with valid attributes" do
      ensure_competition_exists()
      changeset = Team.changeset(%Team{}, %{name: "Test", code: "TST", flag: "test.png", group: "A"})
      assert changeset.valid?
    end

    test "changeset validates group inclusion" do
      changeset = Team.changeset(%Team{}, %{group: "Z"})
      assert %{group: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "GroupPrediction" do
    test "create_changeset with valid attributes" do
      user = user_fixture()
      match = match_fixture()

      changeset =
        GroupPrediction.create_changeset(%GroupPrediction{}, %{
          user_id: user.id,
          match_id: match.id,
          home_score: 2,
          away_score: 1,
          result: "home"
        })

      assert changeset.valid?
    end
  end

  describe "PlayoffPrediction" do
    test "create_changeset with valid attributes" do
      user = user_fixture()
      team = team_fixture()

      changeset =
        PlayoffPrediction.create_changeset(%PlayoffPrediction{}, %{
          user_id: user.id,
          team_id: team.id,
          phase: 16
        })

      assert changeset.valid?
    end
  end

  describe "PlayoffResult" do
    test "create_changeset with valid attributes" do
      ensure_competition_exists()
      team = team_fixture()

      changeset =
        PlayoffResult.create_changeset(%PlayoffResult{}, %{
          team_id: team.id,
          phase: 16,
          competition_id: Jalka2026.Competitions.current_id()
        })

      assert changeset.valid?
    end
  end

  describe "Competition" do
    test "changeset with valid attributes" do
      changeset =
        Competition.changeset(%Competition{}, %{
          id: "test-comp",
          name: "Test Competition",
          short_name: "TC 2026",
          type: "world_cup",
          year: 2026
        })

      assert changeset.valid?
    end

    test "changeset validates required fields" do
      changeset = Competition.changeset(%Competition{}, %{})
      errors = errors_on(changeset)
      assert "can't be blank" in errors.id
      assert "can't be blank" in errors.name
      assert "can't be blank" in errors.short_name
      assert "can't be blank" in errors.type
      assert "can't be blank" in errors.year
    end

    test "changeset validates type inclusion" do
      changeset =
        Competition.changeset(%Competition{}, %{
          id: "test",
          name: "Test",
          short_name: "T",
          type: "invalid",
          year: 2026
        })

      assert %{type: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "HistoricalMatch" do
    test "changeset with valid attributes" do
      changeset =
        HistoricalMatch.changeset(%HistoricalMatch{}, %{
          home_team_code: "GER",
          away_team_code: "FRA",
          home_team_name: "Germany",
          away_team_name: "France",
          home_score: 1,
          away_score: 0,
          date: ~D[2024-06-15],
          competition: "Friendly"
        })

      assert changeset.valid?
    end

    test "changeset validates required fields" do
      changeset = HistoricalMatch.changeset(%HistoricalMatch{}, %{})
      errors = errors_on(changeset)
      assert "can't be blank" in errors.home_team_code
      assert "can't be blank" in errors.away_team_code
      assert "can't be blank" in errors.home_score
      assert "can't be blank" in errors.away_score
      assert "can't be blank" in errors.date
      assert "can't be blank" in errors.competition
    end
  end

  describe "TournamentStanding" do
    test "changeset with valid attributes" do
      changeset =
        TournamentStanding.changeset(%TournamentStanding{}, %{
          tournament_id: "WC-2022",
          tournament_name: "FIFA World Cup 2022",
          position: 1,
          team_code: "ARG",
          team_name: "Argentina"
        })

      assert changeset.valid?
    end

    test "changeset validates required fields" do
      changeset = TournamentStanding.changeset(%TournamentStanding{}, %{})
      errors = errors_on(changeset)
      assert "can't be blank" in errors.tournament_id
      assert "can't be blank" in errors.tournament_name
      assert "can't be blank" in errors.position
      assert "can't be blank" in errors.team_code
      assert "can't be blank" in errors.team_name
    end

    test "changeset validates position in range 1..4" do
      attrs = %{
        tournament_id: "WC-2022",
        tournament_name: "FIFA World Cup 2022",
        position: 5,
        team_code: "ARG",
        team_name: "Argentina"
      }

      changeset = TournamentStanding.changeset(%TournamentStanding{}, attrs)
      assert %{position: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "BracketPrediction" do
    test "changeset with valid attributes" do
      user = user_fixture()
      team = team_fixture()

      changeset =
        BracketPrediction.changeset(%BracketPrediction{}, %{
          user_id: user.id,
          team_id: team.id,
          round: "round_of_16",
          position: 1
        })

      assert changeset.valid?
    end

    test "changeset validates round inclusion" do
      changeset =
        BracketPrediction.changeset(%BracketPrediction{}, %{
          round: "invalid_round",
          position: 1,
          user_id: 1
        })

      assert %{round: ["is invalid"]} = errors_on(changeset)
    end

    test "changeset validates position for round" do
      user = user_fixture()

      changeset =
        BracketPrediction.changeset(%BracketPrediction{}, %{
          user_id: user.id,
          round: "final",
          position: 5
        })

      assert %{position: ["invalid position for round final"]} = errors_on(changeset)
    end

    test "rounds/0 returns all valid rounds" do
      rounds = BracketPrediction.rounds()
      assert "round_of_32" in rounds
      assert "round_of_16" in rounds
      assert "quarter_final" in rounds
      assert "semi_final" in rounds
      assert "final" in rounds
      assert "winner" in rounds
    end

    test "positions_for_round/1 returns correct positions" do
      assert BracketPrediction.positions_for_round("round_of_32") == 16
      assert BracketPrediction.positions_for_round("round_of_16") == 8
      assert BracketPrediction.positions_for_round("quarter_final") == 4
      assert BracketPrediction.positions_for_round("semi_final") == 2
      assert BracketPrediction.positions_for_round("final") == 1
      assert BracketPrediction.positions_for_round("winner") == 1
      assert BracketPrediction.positions_for_round("unknown") == 0
    end

    test "next_round/1 returns the correct next round" do
      assert BracketPrediction.next_round("round_of_32") == "round_of_16"
      assert BracketPrediction.next_round("round_of_16") == "quarter_final"
      assert BracketPrediction.next_round("quarter_final") == "semi_final"
      assert BracketPrediction.next_round("semi_final") == "final"
      assert BracketPrediction.next_round("final") == "winner"
      assert BracketPrediction.next_round("winner") == nil
      assert BracketPrediction.next_round("unknown") == nil
    end

    test "round_display_name/1 returns Estonian names" do
      assert BracketPrediction.round_display_name("round_of_32") == "32 parimat"
      assert BracketPrediction.round_display_name("round_of_16") == "Kaheksandikfinaal"
      assert BracketPrediction.round_display_name("quarter_final") == "Veerandfinaal"
      assert BracketPrediction.round_display_name("semi_final") == "Poolfinaal"
      assert BracketPrediction.round_display_name("final") == "Finaal"
      assert BracketPrediction.round_display_name("winner") == "Võitja"
      assert BracketPrediction.round_display_name("unknown") == "unknown"
    end
  end

  describe "BracketResult" do
    test "changeset with valid attributes" do
      changeset =
        BracketResult.changeset(%BracketResult{}, %{
          round: "round_of_16",
          position: 1,
          competition_id: Jalka2026.Competitions.current_id()
        })

      assert changeset.valid?
    end

    test "changeset validates round inclusion" do
      changeset = BracketResult.changeset(%BracketResult{}, %{round: "invalid", position: 1})
      assert %{round: ["is invalid"]} = errors_on(changeset)
    end

    test "rounds/0 returns all valid rounds" do
      rounds = BracketResult.rounds()
      assert length(rounds) == 6
    end
  end

  describe "UserBadge" do
    test "changeset with valid attributes" do
      user = user_fixture()

      changeset =
        UserBadge.changeset(%UserBadge{}, %{
          user_id: user.id,
          badge_type: "perfect_match",
          awarded_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        })

      assert changeset.valid?
    end

    test "changeset validates badge_type inclusion" do
      changeset =
        UserBadge.changeset(%UserBadge{}, %{
          user_id: 1,
          badge_type: "invalid_badge",
          awarded_at: NaiveDateTime.utc_now()
        })

      assert %{badge_type: ["is invalid"]} = errors_on(changeset)
    end

    test "badge_types/0 returns all badge types" do
      types = UserBadge.badge_types()
      assert "perfect_match" in types
      assert "prophet" in types
      assert "underdog_picker" in types
      assert "streak_master" in types
      assert "group_guru" in types
      assert "playoff_oracle" in types
      assert "first_blood" in types
    end

    test "badge_info/1 returns correct info for each badge type" do
      assert %{name: "Täpne Lask", icon: "🎯"} = UserBadge.badge_info("perfect_match")
      assert %{name: "Prohvet", icon: "🔮"} = UserBadge.badge_info("prophet")
      assert %{name: "Üllataja", icon: "⚡"} = UserBadge.badge_info("underdog_picker")
      assert %{name: "Seeriameister", icon: "🔥"} = UserBadge.badge_info("streak_master")
      assert %{name: "Grupiguru", icon: "🏆"} = UserBadge.badge_info("group_guru")
      assert %{name: "Playoffi Oraakel", icon: "🌟"} = UserBadge.badge_info("playoff_oracle")
      assert %{name: "Esimene Veri", icon: "💫"} = UserBadge.badge_info("first_blood")
      assert %{name: "Tundmatu", icon: "❓"} = UserBadge.badge_info("unknown")
    end
  end

  describe "UserFavoriteTeam" do
    test "changeset with valid attributes" do
      user = user_fixture()
      team = team_fixture()

      changeset =
        UserFavoriteTeam.changeset(%UserFavoriteTeam{}, %{
          user_id: user.id,
          team_id: team.id,
          is_primary: true
        })

      assert changeset.valid?
    end

    test "changeset validates required fields" do
      changeset = UserFavoriteTeam.changeset(%UserFavoriteTeam{}, %{})
      errors = errors_on(changeset)
      assert "can't be blank" in errors.user_id
      assert "can't be blank" in errors.team_id
    end
  end

  describe "UserRivalry" do
    test "changeset with valid attributes" do
      user1 = user_fixture()
      user2 = user_fixture()

      changeset =
        UserRivalry.changeset(%UserRivalry{}, %{
          user_id: user1.id,
          rival_id: user2.id
        })

      assert changeset.valid?
    end

    test "changeset validates cannot rival yourself" do
      user = user_fixture()

      changeset =
        UserRivalry.changeset(%UserRivalry{}, %{
          user_id: user.id,
          rival_id: user.id
        })

      assert %{rival_id: ["cannot rival yourself"]} = errors_on(changeset)
    end

    test "changeset validates status inclusion" do
      changeset =
        UserRivalry.changeset(%UserRivalry{}, %{
          user_id: 1,
          rival_id: 2,
          status: "invalid"
        })

      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "default status is active" do
      changeset = UserRivalry.changeset(%UserRivalry{}, %{user_id: 1, rival_id: 2})
      assert Ecto.Changeset.get_field(changeset, :status) == "active"
    end
  end

  describe "UserStreak" do
    test "changeset with valid attributes" do
      user = user_fixture()

      changeset =
        UserStreak.changeset(%UserStreak{}, %{
          user_id: user.id,
          current_streak: 3,
          longest_streak: 5,
          bonus_points: 1
        })

      assert changeset.valid?
    end

    test "changeset validates non-negative values" do
      changeset =
        UserStreak.changeset(%UserStreak{}, %{
          user_id: 1,
          current_streak: -1
        })

      assert %{current_streak: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "changeset validates required user_id" do
      changeset = UserStreak.changeset(%UserStreak{}, %{})
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "Jalka2026.Chat.Comment" do
    alias Jalka2026.Chat.Comment

    test "changeset with valid attributes" do
      user = user_fixture()
      match = match_fixture()

      changeset =
        Comment.changeset(%Comment{}, %{
          content: "Great match!",
          user_id: user.id,
          match_id: match.id
        })

      assert changeset.valid?
    end

    test "changeset validates required fields" do
      changeset = Comment.changeset(%Comment{}, %{})
      errors = errors_on(changeset)
      assert "can't be blank" in errors.content
      assert "can't be blank" in errors.user_id
      assert "can't be blank" in errors.match_id
    end

    test "changeset validates content length min" do
      changeset = Comment.changeset(%Comment{}, %{content: "x", user_id: 1, match_id: 1})
      # Single character should be valid
      assert changeset.valid?
    end

    test "changeset validates content length max" do
      long_content = String.duplicate("a", 501)
      changeset = Comment.changeset(%Comment{}, %{content: long_content, user_id: 1, match_id: 1})
      errors = errors_on(changeset)
      assert "should be at most 500 character(s)" in errors.content
    end
  end
end

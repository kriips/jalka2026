defmodule Jalka2026.Seed.ParserTest do
  use ExUnit.Case, async: true

  alias Jalka2026.Seed.Parser

  describe "normalize_matches/1" do
    test "returns bare list as-is" do
      matches = [%{"id" => 1}, %{"id" => 2}]
      assert Parser.normalize_matches(matches) == matches
    end

    test "unwraps object with 'matches' key" do
      matches = [%{"id" => 1}]
      assert Parser.normalize_matches(%{"matches" => matches}) == matches
    end

    test "returns empty list for unexpected shape" do
      assert Parser.normalize_matches(%{"other" => "data"}) == []
      assert Parser.normalize_matches("not a map") == []
    end
  end

  describe "build_team_groups/1" do
    test "extracts team groups from GROUP_STAGE matches" do
      matches = [
        %{
          "stage" => "GROUP_STAGE",
          "group" => "GROUP_A",
          "homeTeam" => %{"id" => 10},
          "awayTeam" => %{"id" => 20}
        },
        %{
          "stage" => "GROUP_STAGE",
          "group" => "GROUP_B",
          "homeTeam" => %{"id" => 30},
          "awayTeam" => %{"id" => 40}
        }
      ]

      result = Parser.build_team_groups(matches)
      assert result == %{10 => "A", 20 => "A", 30 => "B", 40 => "B"}
    end

    test "skips non-GROUP_STAGE matches" do
      matches = [
        %{
          "stage" => "ROUND_OF_16",
          "group" => "GROUP_A",
          "homeTeam" => %{"id" => 10},
          "awayTeam" => %{"id" => 20}
        }
      ]

      assert Parser.build_team_groups(matches) == %{}
    end

    test "skips teams with nil IDs" do
      matches = [
        %{
          "stage" => "GROUP_STAGE",
          "group" => "GROUP_A",
          "homeTeam" => %{"id" => nil},
          "awayTeam" => %{"id" => 20}
        }
      ]

      result = Parser.build_team_groups(matches)
      assert result == %{20 => "A"}
    end

    test "deduplicates teams appearing in multiple matches" do
      matches = [
        %{
          "stage" => "GROUP_STAGE",
          "group" => "GROUP_A",
          "homeTeam" => %{"id" => 10},
          "awayTeam" => %{"id" => 20}
        },
        %{
          "stage" => "GROUP_STAGE",
          "group" => "GROUP_A",
          "homeTeam" => %{"id" => 10},
          "awayTeam" => %{"id" => 30}
        }
      ]

      result = Parser.build_team_groups(matches)
      assert result == %{10 => "A", 20 => "A", 30 => "A"}
    end
  end

  describe "parse_allowed_users/1" do
    test "extracts names from user maps" do
      data = [
        %{"id" => 1, "name" => "Alice"},
        %{"id" => 2, "name" => "Bob"}
      ]

      assert Parser.parse_allowed_users(data) == ["Alice", "Bob"]
    end

    test "handles empty list" do
      assert Parser.parse_allowed_users([]) == []
    end
  end

  describe "parse_teams/2" do
    test "parses teams with group from team_groups map" do
      raw = [
        %{
          "id" => 100,
          "name" => "Brazil",
          "tla" => "BRA",
          "area" => %{"code" => "BRA"},
          "crest" => "https://example.com/bra.png"
        }
      ]

      team_groups = %{100 => "A"}
      [team] = Parser.parse_teams(raw, team_groups)

      assert team.id == 100
      assert team.name == "Brazil"
      assert team.code == "BRA"
      assert team.flag == "/images/flags/br.svg"
      assert team.group == "A"
    end

    test "parses teams wrapped in object" do
      raw = %{
        "teams" => [
          %{
            "id" => 200,
            "name" => "France",
            "tla" => "FRA",
            "area" => %{"code" => "FRA"},
            "group" => "C"
          }
        ]
      }

      [team] = Parser.parse_teams(raw, %{})

      assert team.id == 200
      assert team.name == "France"
      assert team.group == "C"
      assert team.flag == "/images/flags/fr.svg"
    end

    test "excludes teams without a group" do
      raw = [
        %{"id" => 300, "name" => "Unknown", "tla" => "UNK", "area" => %{"code" => "UNK"}}
      ]

      assert Parser.parse_teams(raw, %{}) == []
    end

    test "uses shortName when tla is missing" do
      raw = [
        %{"id" => 400, "name" => "Test Team", "shortName" => "TST", "area" => %{"code" => "USA"}}
      ]

      [team] = Parser.parse_teams(raw, %{400 => "D"})
      assert team.code == "TST"
    end

    test "falls back to truncated name when tla and shortName are missing" do
      raw = [
        %{"id" => 500, "name" => "Germany", "area" => %{"code" => "DEU"}}
      ]

      [team] = Parser.parse_teams(raw, %{500 => "E"})
      assert team.code == "GER"
    end

    test "uses crest URL when area code has no flag mapping" do
      raw = [
        %{
          "id" => 600,
          "name" => "Ruritania",
          "tla" => "RUR",
          "area" => %{"code" => "RUR"},
          "crest" => "https://example.com/rur.png"
        }
      ]

      [team] = Parser.parse_teams(raw, %{600 => "F"})
      assert team.flag == "https://example.com/rur.png"
    end
  end

  describe "parse_group_matches/1" do
    test "parses GROUP_STAGE matches" do
      matches = [
        %{
          "stage" => "GROUP_STAGE",
          "group" => "GROUP_A",
          "homeTeam" => %{"id" => 10},
          "awayTeam" => %{"id" => 20},
          "utcDate" => "2026-06-11T19:00:00Z"
        }
      ]

      [match] = Parser.parse_group_matches(matches)

      assert match.group == "Alagrupp A"
      assert match.home_team_id == 10
      assert match.away_team_id == 20
      assert %NaiveDateTime{} = match.date
    end

    test "excludes non-group-stage matches" do
      matches = [
        %{
          "stage" => "ROUND_OF_16",
          "group" => "GROUP_A",
          "homeTeam" => %{"id" => 10},
          "awayTeam" => %{"id" => 20}
        }
      ]

      assert Parser.parse_group_matches(matches) == []
    end

    test "excludes matches with missing team IDs" do
      matches = [
        %{
          "stage" => "GROUP_STAGE",
          "group" => "GROUP_A",
          "homeTeam" => %{"id" => nil},
          "awayTeam" => %{"id" => 20}
        }
      ]

      assert Parser.parse_group_matches(matches) == []
    end

    test "handles nil utcDate" do
      matches = [
        %{
          "stage" => "GROUP_STAGE",
          "group" => "GROUP_B",
          "homeTeam" => %{"id" => 10},
          "awayTeam" => %{"id" => 20},
          "utcDate" => nil
        }
      ]

      [match] = Parser.parse_group_matches(matches)
      assert match.date == nil
    end
  end

  describe "parse_historical_matches/1" do
    test "parses historical match data" do
      data = [
        %{
          "home_team_code" => "FRA",
          "away_team_code" => "MEX",
          "home_team_name" => "France",
          "away_team_name" => "Mexico",
          "home_score" => 4,
          "away_score" => 1,
          "date" => "1930-07-13",
          "competition" => "1930 FIFA Men's World Cup",
          "stage" => "group stage",
          "venue" => "Estadio Pocitos, Montevideo, Uruguay",
          "is_world_cup" => true
        }
      ]

      [match] = Parser.parse_historical_matches(data)

      assert match.home_team_code == "FRA"
      assert match.away_team_code == "MEX"
      assert match.home_score == 4
      assert match.away_score == 1
      assert match.date == ~D[1930-07-13]
      assert match.is_world_cup == true
    end

    test "handles nil date" do
      data = [
        %{
          "home_team_code" => "A",
          "away_team_code" => "B",
          "home_team_name" => "A",
          "away_team_name" => "B",
          "home_score" => 0,
          "away_score" => 0,
          "date" => nil,
          "competition" => "Test",
          "stage" => "final",
          "venue" => "Test",
          "is_world_cup" => false
        }
      ]

      [match] = Parser.parse_historical_matches(data)
      assert match.date == nil
    end

    test "defaults is_world_cup to false when missing" do
      data = [
        %{
          "home_team_code" => "A",
          "away_team_code" => "B",
          "home_team_name" => "A",
          "away_team_name" => "B",
          "home_score" => 0,
          "away_score" => 0,
          "date" => "2000-01-01",
          "competition" => "Friendly",
          "stage" => "friendly",
          "venue" => "Test"
        }
      ]

      [match] = Parser.parse_historical_matches(data)
      assert match.is_world_cup == false
    end
  end

  describe "parse_tournament_standings/1" do
    test "parses tournament standings" do
      data = [
        %{
          "tournament_id" => "WC-1930",
          "tournament_name" => "1930 FIFA Men's World Cup",
          "position" => 1,
          "team_code" => "URY",
          "team_name" => "Uruguay"
        }
      ]

      [standing] = Parser.parse_tournament_standings(data)

      assert standing.tournament_id == "WC-1930"
      assert standing.tournament_name == "1930 FIFA Men's World Cup"
      assert standing.position == 1
      assert standing.team_code == "URY"
      assert standing.team_name == "Uruguay"
    end
  end

  describe "default_competition_attrs/1" do
    test "returns competition attributes with provided ID" do
      attrs = Parser.default_competition_attrs("wc-2026")

      assert attrs.id == "wc-2026"
      assert attrs.name == "FIFA World Cup 2026"
      assert attrs.year == 2026
      assert attrs.is_active == true
    end
  end
end

defmodule Jalka2026.Seed.Parser do
  @moduledoc """
  Pure data transformations for seed data.

  All functions in this module are side-effect-free: they accept raw JSON data
  (already decoded maps/lists) and return normalised, insert-ready data structures.
  This makes them fully testable without a database.

  ## Usage

      raw = Jason.decode!(File.read!("priv/repo/data/teams.json"))
      matches_raw = Jason.decode!(File.read!("priv/repo/data/matches.json"))
      team_groups = Jalka2026.Seed.Parser.build_team_groups(matches_raw)
      teams = Jalka2026.Seed.Parser.parse_teams(raw, team_groups)
  """

  # Map team area codes to ISO 2-letter country codes for local flag files
  @team_area_to_flag %{
    "URY" => "uy",
    "DEU" => "de",
    "ESP" => "es",
    "PRY" => "py",
    "ARG" => "ar",
    "GHA" => "gh",
    "BRA" => "br",
    "POR" => "pt",
    "JPN" => "jp",
    "MEX" => "mx",
    "ENG" => "gb-eng",
    "USA" => "us",
    "KOR" => "kr",
    "FRA" => "fr",
    "RSA" => "za",
    "ALG" => "dz",
    "AUS" => "au",
    "NZL" => "nz",
    "CHE" => "ch",
    "ECU" => "ec",
    "HRV" => "hr",
    "KSA" => "sa",
    "TUN" => "tn",
    "SEN" => "sn",
    "BEL" => "be",
    "MAR" => "ma",
    "AUT" => "at",
    "COL" => "co",
    "EGY" => "eg",
    "CAN" => "ca",
    "HTI" => "ht",
    "IRN" => "ir",
    "PAN" => "pa",
    "CPV" => "cv",
    "CIV" => "ci",
    "QAT" => "qa",
    "JOR" => "jo",
    "UZB" => "uz",
    "NLD" => "nl",
    "NOR" => "no",
    "SCO" => "gb-sct",
    "ANT" => "cw"
  }

  # -------------------------------------------------------------------
  # Matches (raw JSON normalization)
  # -------------------------------------------------------------------

  @doc """
  Normalise raw matches JSON into a plain list.

  The football-data.org API wraps matches in `{"matches": [...]}` while
  some local fixtures use a bare array. This function handles both.
  """
  @spec normalize_matches(map() | list()) :: [map()]
  def normalize_matches(data) when is_list(data), do: data
  def normalize_matches(%{"matches" => matches}) when is_list(matches), do: matches
  def normalize_matches(_), do: []

  # -------------------------------------------------------------------
  # Team groups
  # -------------------------------------------------------------------

  @doc """
  Build a `%{team_id => group_letter}` map from raw match data.

  Only GROUP_STAGE matches are considered. Teams without an ID are skipped.

  ## Examples

      iex> matches = [%{"stage" => "GROUP_STAGE", "group" => "GROUP_A",
      ...>              "homeTeam" => %{"id" => 1}, "awayTeam" => %{"id" => 2}}]
      iex> Jalka2026.Seed.Parser.build_team_groups(matches)
      %{1 => "A", 2 => "A"}
  """
  @spec build_team_groups([map()]) :: %{integer() => String.t()}
  def build_team_groups(matches) do
    matches
    |> Enum.filter(&(&1["stage"] == "GROUP_STAGE"))
    |> Enum.flat_map(fn match ->
      group = match["group"] |> String.replace("GROUP_", "")

      [
        {match["homeTeam"]["id"], group},
        {match["awayTeam"]["id"], group}
      ]
    end)
    |> Enum.reject(fn {id, _} -> is_nil(id) end)
    |> Enum.into(%{})
  end

  # -------------------------------------------------------------------
  # Allowed users
  # -------------------------------------------------------------------

  @doc """
  Parse allowed users JSON into a list of name strings.

  ## Examples

      iex> Jalka2026.Seed.Parser.parse_allowed_users([%{"id" => 1, "name" => "Alice"}])
      ["Alice"]
  """
  @spec parse_allowed_users([map()]) :: [String.t()]
  def parse_allowed_users(data) do
    Enum.map(data, & &1["name"])
  end

  # -------------------------------------------------------------------
  # Teams
  # -------------------------------------------------------------------

  @doc """
  Parse teams JSON into insert-ready maps.

  Each result map has keys: `:id`, `:name`, `:code`, `:flag`, `:group`.
  Teams without a group assignment are excluded.

  `team_groups` is the output of `build_team_groups/1`.
  `raw_data` can be either a bare list or `%{"teams" => [...]}`.
  """
  @spec parse_teams(map() | list(), %{integer() => String.t()}) :: [map()]
  def parse_teams(raw_data, team_groups) do
    teams = if is_list(raw_data), do: raw_data, else: Map.get(raw_data, "teams", [])

    teams
    |> Enum.map(fn attrs ->
      team_id = Map.get(attrs, "id")
      group = Map.get(attrs, "group") || Map.get(team_groups, team_id)

      code =
        Map.get(attrs, "tla") || Map.get(attrs, "shortName") ||
          String.slice(Map.get(attrs, "name", "UNK"), 0, 3) |> String.upcase()

      area_code = get_in(attrs, ["area", "code"])
      flag = local_flag_path(area_code) || Map.get(attrs, "crest")

      %{id: team_id, name: Map.get(attrs, "name"), code: code, flag: flag, group: group}
    end)
    |> Enum.filter(& &1.group)
  end

  # -------------------------------------------------------------------
  # Group-stage matches
  # -------------------------------------------------------------------

  @doc """
  Parse group-stage matches into insert-ready maps.

  Each result map has keys: `:group`, `:home_team_id`, `:away_team_id`, `:date`.
  Non-group-stage matches and matches with missing team IDs are excluded.
  """
  @spec parse_group_matches([map()]) :: [map()]
  def parse_group_matches(matches) do
    matches
    |> Enum.filter(fn m ->
      m["stage"] == "GROUP_STAGE" &&
        get_in(m, ["homeTeam", "id"]) &&
        get_in(m, ["awayTeam", "id"])
    end)
    |> Enum.map(fn attrs ->
      group_letter = attrs["group"] |> String.replace("GROUP_", "")

      %{
        group: "Alagrupp #{group_letter}",
        home_team_id: get_in(attrs, ["homeTeam", "id"]),
        away_team_id: get_in(attrs, ["awayTeam", "id"]),
        date: parse_naive_datetime(Map.get(attrs, "utcDate"))
      }
    end)
  end

  # -------------------------------------------------------------------
  # Historical matches
  # -------------------------------------------------------------------

  @doc """
  Parse historical matches JSON into insert-ready maps.

  Each result map mirrors the `historical_matches` table columns.
  """
  @spec parse_historical_matches([map()]) :: [map()]
  def parse_historical_matches(data) do
    Enum.map(data, fn attrs ->
      %{
        home_team_code: Map.get(attrs, "home_team_code"),
        away_team_code: Map.get(attrs, "away_team_code"),
        home_team_name: Map.get(attrs, "home_team_name"),
        away_team_name: Map.get(attrs, "away_team_name"),
        home_score: Map.get(attrs, "home_score"),
        away_score: Map.get(attrs, "away_score"),
        date: parse_date(Map.get(attrs, "date")),
        competition: Map.get(attrs, "competition"),
        stage: Map.get(attrs, "stage"),
        venue: Map.get(attrs, "venue"),
        is_world_cup: Map.get(attrs, "is_world_cup", false)
      }
    end)
  end

  # -------------------------------------------------------------------
  # Tournament standings
  # -------------------------------------------------------------------

  @doc """
  Parse tournament standings JSON into insert-ready maps.
  """
  @spec parse_tournament_standings([map()]) :: [map()]
  def parse_tournament_standings(data) do
    Enum.map(data, fn attrs ->
      %{
        tournament_id: Map.get(attrs, "tournament_id"),
        tournament_name: Map.get(attrs, "tournament_name"),
        position: Map.get(attrs, "position"),
        team_code: Map.get(attrs, "team_code"),
        team_name: Map.get(attrs, "team_name")
      }
    end)
  end

  # -------------------------------------------------------------------
  # Competition
  # -------------------------------------------------------------------

  @doc """
  Returns default competition attributes.
  """
  @spec default_competition_attrs(String.t()) :: map()
  def default_competition_attrs(competition_id) do
    %{
      id: competition_id,
      name: "FIFA World Cup 2026",
      short_name: "MM 2026",
      type: "world_cup",
      year: 2026,
      start_date: ~D[2026-06-11],
      end_date: ~D[2026-07-19],
      prediction_deadline: ~U[2026-06-11 19:00:00Z],
      is_active: true
    }
  end

  # -------------------------------------------------------------------
  # Helpers (private, pure)
  # -------------------------------------------------------------------

  defp local_flag_path(area_code) when is_binary(area_code) do
    case Map.get(@team_area_to_flag, area_code) do
      nil -> nil
      iso_code -> "/images/flags/#{iso_code}.svg"
    end
  end

  defp local_flag_path(_), do: nil

  defp parse_naive_datetime(nil), do: nil
  defp parse_naive_datetime(d) when is_binary(d), do: NaiveDateTime.from_iso8601!(d)
  defp parse_naive_datetime(d), do: d

  defp parse_date(nil), do: nil
  defp parse_date(d) when is_binary(d), do: Date.from_iso8601!(d)
  defp parse_date(d), do: d
end

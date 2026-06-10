defmodule Jalka2026.Football.BracketSeeding do
  @moduledoc """
  Defines the official FIFA 2026 World Cup knockout bracket structure.

  Maps group stage qualifiers to their Round of 32 positions based on
  the official FIFA draw procedure.

  Bracket positions use the BracketPrediction position numbering:
  - round_of_32: positions 1-16 (16 matchups)
  - round_of_16: positions 1-8 (8 matchups)
  - quarter_final: positions 1-4
  - semi_final: positions 1-2
  - final: position 1
  """

  alias Jalka2026.Football.ThirdPlaceSeeding

  @official_version "official_2026"
  @legacy_version "legacy_2026"

  # 8 group winners face 3rd place teams
  # 4 group winners (C, F, H, J) face runners-up from other groups
  # 4 runner-up vs runner-up matches

  # Each R32 matchup: {position, home_seed, away_seed}
  # Seeds: {:winner, group}, {:runner_up, group}, {:third, :vs_1X}
  #
  # Positions are the existing UI/storage slots. They are not official FIFA
  # match-number order, so advancement_path/0 below maps the slots into the
  # official bracket feed.
  @official_r32_structure [
    # FIFA match 79: 1A v 3CEFHI
    {1, {:winner, "A"}, {:third, :vs_1A}},
    # FIFA match 76: 1C v 2F
    {2, {:winner, "C"}, {:runner_up, "F"}},
    # FIFA match 85: 1B v 3EFGIJ
    {3, {:winner, "B"}, {:third, :vs_1B}},
    # FIFA match 75: 1F v 2C
    {4, {:winner, "F"}, {:runner_up, "C"}},
    # FIFA match 81: 1D v 3BEFIJ
    {5, {:winner, "D"}, {:third, :vs_1D}},
    # FIFA match 84: 1H v 2J
    {6, {:winner, "H"}, {:runner_up, "J"}},
    # FIFA match 74: 1E v 3ABCDF
    {7, {:winner, "E"}, {:third, :vs_1E}},
    # FIFA match 86: 1J v 2H
    {8, {:winner, "J"}, {:runner_up, "H"}},
    # FIFA match 82: 1G v 3AEHIJ
    {9, {:winner, "G"}, {:third, :vs_1G}},
    # FIFA match 73: 2A v 2B
    {10, {:runner_up, "A"}, {:runner_up, "B"}},
    # FIFA match 77: 1I v 3CDFGH
    {11, {:winner, "I"}, {:third, :vs_1I}},
    # FIFA match 78: 2E v 2I
    {12, {:runner_up, "E"}, {:runner_up, "I"}},
    # FIFA match 87: 1K v 3DEIJL
    {13, {:winner, "K"}, {:third, :vs_1K}},
    # FIFA match 88: 2D v 2G
    {14, {:runner_up, "D"}, {:runner_up, "G"}},
    # FIFA match 80: 1L v 3EHIJK
    {15, {:winner, "L"}, {:third, :vs_1L}},
    # FIFA match 83: 2K v 2L
    {16, {:runner_up, "K"}, {:runner_up, "L"}}
  ]

  @legacy_r32_structure [
    {1, {:winner, "A"}, {:third, :vs_1A}},
    {2, {:winner, "C"}, {:runner_up, "F"}},
    {3, {:winner, "B"}, {:third, :vs_1B}},
    {4, {:winner, "F"}, {:runner_up, "C"}},
    {5, {:winner, "D"}, {:third, :vs_1D}},
    {6, {:winner, "H"}, {:runner_up, "J"}},
    {7, {:winner, "E"}, {:third, :vs_1E}},
    {8, {:winner, "J"}, {:runner_up, "H"}},
    {9, {:winner, "G"}, {:third, :vs_1G}},
    {10, {:runner_up, "A"}, {:runner_up, "B"}},
    {11, {:winner, "I"}, {:third, :vs_1I}},
    {12, {:runner_up, "E"}, {:runner_up, "D"}},
    {13, {:winner, "K"}, {:third, :vs_1K}},
    {14, {:runner_up, "G"}, {:runner_up, "L"}},
    {15, {:winner, "L"}, {:third, :vs_1L}},
    {16, {:runner_up, "I"}, {:runner_up, "K"}}
  ]

  @doc "Current corrected 2026 bracket version."
  def official_version, do: @official_version

  @doc "Legacy bracket version used to preserve already-entered playoff predictions."
  def legacy_version, do: @legacy_version

  @doc """
  Returns the R32 bracket structure as a list of
  `{position, home_seed, away_seed}` tuples.
  """
  def r32_structure(version \\ @official_version) do
    if legacy_version?(version), do: @legacy_r32_structure, else: @official_r32_structure
  end

  @doc """
  Given group standings (map of group => ranked team list) and the 8 qualifying
  third-place groups, resolve all R32 matchups to actual teams.

  ## Parameters
  - `standings` - Map of %{"A" => [team_1st, team_2nd, team_3rd, team_4th], ...}
  - `third_place_groups` - List of 8 group letters whose 3rd place teams qualify

  ## Returns
  List of `{position, home_team, away_team}` or `{position, home_team, nil}` if
  a 3rd place team can't be determined.
  """
  def resolve_r32_matchups(standings, third_place_groups, version \\ @official_version) do
    seeding = ThirdPlaceSeeding.get_seeding(third_place_groups)

    # Build a lookup: :vs_1A => the actual 3rd place team assigned to that slot
    third_place_lookup = build_third_place_lookup(standings, third_place_groups, seeding)

    Enum.map(r32_structure(version), fn {pos, home_seed, away_seed} ->
      home = resolve_seed(home_seed, standings, third_place_lookup)
      away = resolve_seed(away_seed, standings, third_place_lookup)
      {pos, home, away}
    end)
  end

  @doc """
  Returns which R32 positions feed into each later round position.

  ## Returns
  Map of `{round, position} => [{source_round, source_pos_1}, {source_round, source_pos_2}]`
  """
  def advancement_path(version \\ @official_version) do
    {r16, qf, sf} =
      if legacy_version?(version) do
        legacy_advancement_rounds()
      else
        official_advancement_rounds()
      end

    f = [{{"final", 1}, [{"semi_final", 1}, {"semi_final", 2}]}]

    Map.new(r16 ++ qf ++ sf ++ f)
  end

  @doc """
  Get the two source positions that feed into a given bracket slot.
  Returns `{source_round_1, source_pos_1, source_round_2, source_pos_2}` or nil.
  """
  def feeder_positions(round, position, version \\ @official_version) do
    case Map.get(advancement_path(version), {round, position}) do
      [{r1, p1}, {r2, p2}] -> {r1, p1, r2, p2}
      nil -> nil
    end
  end

  # Private helpers

  defp legacy_version?(version), do: version == @legacy_version or version == :legacy_2026

  defp official_advancement_rounds do
    r16 = [
      # FIFA match 89: W74 v W77
      {{"round_of_16", 1}, [{"round_of_32", 7}, {"round_of_32", 11}]},
      # FIFA match 90: W73 v W75
      {{"round_of_16", 2}, [{"round_of_32", 10}, {"round_of_32", 4}]},
      # FIFA match 93: W83 v W84
      {{"round_of_16", 3}, [{"round_of_32", 16}, {"round_of_32", 6}]},
      # FIFA match 94: W81 v W82
      {{"round_of_16", 4}, [{"round_of_32", 5}, {"round_of_32", 9}]},
      # FIFA match 91: W76 v W78
      {{"round_of_16", 5}, [{"round_of_32", 2}, {"round_of_32", 12}]},
      # FIFA match 92: W79 v W80
      {{"round_of_16", 6}, [{"round_of_32", 1}, {"round_of_32", 15}]},
      # FIFA match 95: W86 v W88
      {{"round_of_16", 7}, [{"round_of_32", 8}, {"round_of_32", 14}]},
      # FIFA match 96: W85 v W87
      {{"round_of_16", 8}, [{"round_of_32", 3}, {"round_of_32", 13}]}
    ]

    qf = [
      # FIFA match 97: W89 v W90
      {{"quarter_final", 1}, [{"round_of_16", 1}, {"round_of_16", 2}]},
      # FIFA match 98: W93 v W94
      {{"quarter_final", 2}, [{"round_of_16", 3}, {"round_of_16", 4}]},
      # FIFA match 99: W91 v W92
      {{"quarter_final", 3}, [{"round_of_16", 5}, {"round_of_16", 6}]},
      # FIFA match 100: W95 v W96
      {{"quarter_final", 4}, [{"round_of_16", 7}, {"round_of_16", 8}]}
    ]

    sf = [
      # FIFA match 101: W97 v W98
      {{"semi_final", 1}, [{"quarter_final", 1}, {"quarter_final", 2}]},
      # FIFA match 102: W99 v W100
      {{"semi_final", 2}, [{"quarter_final", 3}, {"quarter_final", 4}]}
    ]

    {r16, qf, sf}
  end

  defp legacy_advancement_rounds do
    r16 =
      for pos <- 1..8,
          do: {{"round_of_16", pos}, [{"round_of_32", 2 * pos - 1}, {"round_of_32", 2 * pos}]}

    qf =
      for pos <- 1..4,
          do: {{"quarter_final", pos}, [{"round_of_16", 2 * pos - 1}, {"round_of_16", 2 * pos}]}

    sf =
      for pos <- 1..2,
          do: {{"semi_final", pos}, [{"quarter_final", 2 * pos - 1}, {"quarter_final", 2 * pos}]}

    {r16, qf, sf}
  end

  defp build_third_place_lookup(standings, _third_place_groups, seeding)
       when is_map(seeding) do
    # seeding is a map like %{a: :E, b: :J, d: :I, e: :F, g: :H, i: :G, k: :L, l: :K}
    # Keys (:a, :b, :d, :e, :g, :i, :k, :l) are group winners facing 3rd-place teams.
    # Values are atoms representing the 3rd-place qualifying group.
    #
    # Map from slot atoms (:vs_1A, :vs_1B, ...) to the actual 3rd place team.
    slot_to_seeding_key = %{
      vs_1A: :a,
      vs_1B: :b,
      vs_1D: :d,
      vs_1E: :e,
      vs_1G: :g,
      vs_1I: :i,
      vs_1K: :k,
      vs_1L: :l
    }

    Enum.reduce(slot_to_seeding_key, %{}, fn {slot, seeding_key}, acc ->
      case Map.get(seeding, seeding_key) do
        nil ->
          acc

        group_atom ->
          group = group_atom |> Atom.to_string() |> String.upcase()
          team = get_team_at_position(standings, group, 3)
          Map.put(acc, slot, team)
      end
    end)
  end

  defp build_third_place_lookup(_standings, _groups, nil), do: %{}

  defp resolve_seed({:winner, group}, standings, _third_lookup) do
    get_team_at_position(standings, group, 1)
  end

  defp resolve_seed({:runner_up, group}, standings, _third_lookup) do
    get_team_at_position(standings, group, 2)
  end

  defp resolve_seed({:third, slot}, _standings, third_lookup) do
    Map.get(third_lookup, slot)
  end

  defp get_team_at_position(standings, group, position) do
    case Map.get(standings, group) do
      teams when is_list(teams) -> Enum.at(teams, position - 1)
      _ -> nil
    end
  end
end

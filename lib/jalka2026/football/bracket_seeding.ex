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

  # 8 group winners face 3rd place teams
  # 4 group winners (C, F, H, J) face runners-up from other groups
  # 4 runner-up vs runner-up matches

  # Each R32 matchup: {position, home_seed, away_seed}
  # Seeds: {:winner, group}, {:runner_up, group}, {:third, :vs_1X}
  @r32_structure [
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

  # Bracket flow: R32 positions feed into R16
  # R16 position N receives winners of R32 positions (2N-1) and (2N)
  # e.g. R16 pos 1 <- R32 pos 1 winner vs R32 pos 2 winner

  @doc """
  Returns the R32 bracket structure as a list of
  `{position, home_seed, away_seed}` tuples.
  """
  def r32_structure, do: @r32_structure

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
  def resolve_r32_matchups(standings, third_place_groups) do
    seeding = ThirdPlaceSeeding.get_seeding(third_place_groups)

    # Build a lookup: :vs_1A => the actual 3rd place team assigned to that slot
    third_place_lookup = build_third_place_lookup(standings, third_place_groups, seeding)

    Enum.map(@r32_structure, fn {pos, home_seed, away_seed} ->
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
  def advancement_path do
    r16 =
      for pos <- 1..8,
          do:
            {{"round_of_16", pos},
             [{"round_of_32", 2 * pos - 1}, {"round_of_32", 2 * pos}]}

    qf =
      for pos <- 1..4,
          do:
            {{"quarter_final", pos},
             [{"round_of_16", 2 * pos - 1}, {"round_of_16", 2 * pos}]}

    sf =
      for pos <- 1..2,
          do:
            {{"semi_final", pos},
             [{"quarter_final", 2 * pos - 1}, {"quarter_final", 2 * pos}]}

    f = [{{"final", 1}, [{"semi_final", 1}, {"semi_final", 2}]}]

    Map.new(r16 ++ qf ++ sf ++ f)
  end

  @doc """
  Get the two source positions that feed into a given bracket slot.
  Returns `{source_round_1, source_pos_1, source_round_2, source_pos_2}` or nil.
  """
  def feeder_positions(round, position) do
    case Map.get(advancement_path(), {round, position}) do
      [{r1, p1}, {r2, p2}] -> {r1, p1, r2, p2}
      nil -> nil
    end
  end

  # Private helpers

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

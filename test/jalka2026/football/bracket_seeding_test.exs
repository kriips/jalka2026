defmodule Jalka2026.Football.BracketSeedingTest do
  use ExUnit.Case, async: true

  alias Jalka2026.Football.BracketSeeding

  describe "r32_structure/0" do
    test "uses the official round-of-32 matchups in existing storage slots" do
      assert BracketSeeding.r32_structure() |> Enum.map(&format_matchup/1) == [
               {1, "1A", "3vs_1A"},
               {2, "1C", "2F"},
               {3, "1B", "3vs_1B"},
               {4, "1F", "2C"},
               {5, "1D", "3vs_1D"},
               {6, "1H", "2J"},
               {7, "1E", "3vs_1E"},
               {8, "1J", "2H"},
               {9, "1G", "3vs_1G"},
               {10, "2A", "2B"},
               {11, "1I", "3vs_1I"},
               {12, "2E", "2I"},
               {13, "1K", "3vs_1K"},
               {14, "2D", "2G"},
               {15, "1L", "3vs_1L"},
               {16, "2K", "2L"}
             ]
    end

    test "can return the legacy structure for users who have not reset old predictions" do
      assert BracketSeeding.r32_structure(BracketSeeding.legacy_version())
             |> Enum.map(&format_matchup/1) == [
               {1, "1A", "3vs_1A"},
               {2, "1C", "2F"},
               {3, "1B", "3vs_1B"},
               {4, "1F", "2C"},
               {5, "1D", "3vs_1D"},
               {6, "1H", "2J"},
               {7, "1E", "3vs_1E"},
               {8, "1J", "2H"},
               {9, "1G", "3vs_1G"},
               {10, "2A", "2B"},
               {11, "1I", "3vs_1I"},
               {12, "2E", "2D"},
               {13, "1K", "3vs_1K"},
               {14, "2G", "2L"},
               {15, "1L", "3vs_1L"},
               {16, "2I", "2K"}
             ]
    end
  end

  describe "feeder_positions/2" do
    test "maps R32 slots into official round-of-16 matches" do
      assert BracketSeeding.feeder_positions("round_of_16", 1) ==
               {"round_of_32", 7, "round_of_32", 11}

      assert BracketSeeding.feeder_positions("round_of_16", 2) ==
               {"round_of_32", 10, "round_of_32", 4}

      assert BracketSeeding.feeder_positions("round_of_16", 3) ==
               {"round_of_32", 16, "round_of_32", 6}

      assert BracketSeeding.feeder_positions("round_of_16", 4) ==
               {"round_of_32", 5, "round_of_32", 9}

      assert BracketSeeding.feeder_positions("round_of_16", 5) ==
               {"round_of_32", 2, "round_of_32", 12}

      assert BracketSeeding.feeder_positions("round_of_16", 6) ==
               {"round_of_32", 1, "round_of_32", 15}

      assert BracketSeeding.feeder_positions("round_of_16", 7) ==
               {"round_of_32", 8, "round_of_32", 14}

      assert BracketSeeding.feeder_positions("round_of_16", 8) ==
               {"round_of_32", 3, "round_of_32", 13}
    end

    test "keeps group H and group J winners on opposite finalist paths" do
      assert path_from_r32_slot(6) == [
               {"round_of_16", 3},
               {"quarter_final", 2},
               {"semi_final", 1},
               {"final", 1}
             ]

      assert path_from_r32_slot(8) == [
               {"round_of_16", 7},
               {"quarter_final", 4},
               {"semi_final", 2},
               {"final", 1}
             ]
    end

    test "preserves the old adjacent feeder graph for legacy users" do
      version = BracketSeeding.legacy_version()

      assert BracketSeeding.feeder_positions("round_of_16", 1, version) ==
               {"round_of_32", 1, "round_of_32", 2}

      assert BracketSeeding.feeder_positions("quarter_final", 1, version) ==
               {"round_of_16", 1, "round_of_16", 2}
    end
  end

  defp format_matchup({position, home_seed, away_seed}) do
    {position, format_seed(home_seed), format_seed(away_seed)}
  end

  defp format_seed({:winner, group}), do: "1#{group}"
  defp format_seed({:runner_up, group}), do: "2#{group}"
  defp format_seed({:third, slot}), do: "3#{slot}"

  defp path_from_r32_slot(slot) do
    path_from_source({"round_of_32", slot}, [
      "round_of_16",
      "quarter_final",
      "semi_final",
      "final"
    ])
  end

  defp path_from_source(_source, []), do: []

  defp path_from_source(source, [round | rest]) do
    position =
      1..positions_for_round(round)
      |> Enum.find(fn pos ->
        BracketSeeding.advancement_path()
        |> Map.fetch!({round, pos})
        |> Enum.member?(source)
      end)

    [{round, position} | path_from_source({round, position}, rest)]
  end

  defp positions_for_round("round_of_16"), do: 8
  defp positions_for_round("quarter_final"), do: 4
  defp positions_for_round("semi_final"), do: 2
  defp positions_for_round("final"), do: 1
end

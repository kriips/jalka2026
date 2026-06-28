defmodule Jalka2026.Football.QualifiersTest do
  use Jalka2026.DataCase

  import Jalka2026.FootballFixtures

  alias Jalka2026.Football.Qualifiers
  alias Jalka2026.Scoring

  describe "actual_last_32/0" do
    test "is empty until the admin marks teams at the last-32 phase" do
      # Teams exist but none are marked as reaching the round of 32.
      team_fixture()
      team_fixture()

      assert Qualifiers.actual_last_32() == []
    end

    test "returns the team ids explicitly marked at the last-32 phase" do
      reached_a = team_fixture()
      reached_b = team_fixture()
      # A team marked at a bracket phase (reached round of 16) must NOT count as last-32.
      other = team_fixture()

      playoff_result_fixture(%{team: reached_a, phase: Scoring.last_32_phase()})
      playoff_result_fixture(%{team: reached_b, phase: Scoring.last_32_phase()})
      playoff_result_fixture(%{team: other, phase: 32})

      marked = Qualifiers.actual_last_32()

      assert Enum.sort(marked) == Enum.sort([reached_a.id, reached_b.id])
      refute other.id in marked
    end
  end
end

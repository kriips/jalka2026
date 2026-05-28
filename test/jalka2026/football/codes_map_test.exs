defmodule Jalka2026.Football.CodesMapTest do
  use ExUnit.Case, async: true

  alias Jalka2026.Football.CodesMap

  describe "fifa_to_iso/1" do
    # Current 2026 WC participants with differing codes
    test "GER -> DEU (Germany)" do
      assert CodesMap.fifa_to_iso("GER") == "DEU"
    end

    test "NED -> NLD (Netherlands)" do
      assert CodesMap.fifa_to_iso("NED") == "NLD"
    end

    test "POR -> PRT (Portugal)" do
      assert CodesMap.fifa_to_iso("POR") == "PRT"
    end

    test "SUI -> CHE (Switzerland)" do
      assert CodesMap.fifa_to_iso("SUI") == "CHE"
    end

    test "CRO -> HRV (Croatia)" do
      assert CodesMap.fifa_to_iso("CRO") == "HRV"
    end

    test "KSA -> SAU (Saudi Arabia)" do
      assert CodesMap.fifa_to_iso("KSA") == "SAU"
    end

    test "RSA -> ZAF (South Africa)" do
      assert CodesMap.fifa_to_iso("RSA") == "ZAF"
    end

    test "ALG -> DZA (Algeria)" do
      assert CodesMap.fifa_to_iso("ALG") == "DZA"
    end

    test "HAI -> HTI (Haiti)" do
      assert CodesMap.fifa_to_iso("HAI") == "HTI"
    end

    test "PAR -> PRY (Paraguay)" do
      assert CodesMap.fifa_to_iso("PAR") == "PRY"
    end

    test "URU -> URY (Uruguay)" do
      assert CodesMap.fifa_to_iso("URU") == "URY"
    end

    test "CUR -> CUW (Curaçao)" do
      assert CodesMap.fifa_to_iso("CUR") == "CUW"
    end

    # Future import safety net
    test "CHI -> CHL (Chile)" do
      assert CodesMap.fifa_to_iso("CHI") == "CHL"
    end

    test "CRC -> CRI (Costa Rica)" do
      assert CodesMap.fifa_to_iso("CRC") == "CRI"
    end

    test "UAE -> ARE (United Arab Emirates)" do
      assert CodesMap.fifa_to_iso("UAE") == "ARE"
    end

    test "PHI -> PHL (Philippines)" do
      assert CodesMap.fifa_to_iso("PHI") == "PHL"
    end

    test "TPE -> TWN (Chinese Taipei)" do
      assert CodesMap.fifa_to_iso("TPE") == "TWN"
    end

    # Passthrough: teams where FIFA == ISO
    test "returns original code for teams where FIFA matches ISO" do
      assert CodesMap.fifa_to_iso("BRA") == "BRA"
      assert CodesMap.fifa_to_iso("FRA") == "FRA"
      assert CodesMap.fifa_to_iso("ARG") == "ARG"
      assert CodesMap.fifa_to_iso("ESP") == "ESP"
      assert CodesMap.fifa_to_iso("ENG") == "ENG"
      assert CodesMap.fifa_to_iso("JPN") == "JPN"
      assert CodesMap.fifa_to_iso("USA") == "USA"
    end
  end

  describe "iso_to_fifa/1" do
    test "DEU -> GER (Germany)" do
      assert CodesMap.iso_to_fifa("DEU") == "GER"
    end

    test "NLD -> NED (Netherlands)" do
      assert CodesMap.iso_to_fifa("NLD") == "NED"
    end

    test "PRT -> POR (Portugal)" do
      assert CodesMap.iso_to_fifa("PRT") == "POR"
    end

    test "CHE -> SUI (Switzerland)" do
      assert CodesMap.iso_to_fifa("CHE") == "SUI"
    end

    test "HRV -> CRO (Croatia)" do
      assert CodesMap.iso_to_fifa("HRV") == "CRO"
    end

    test "SAU -> KSA (Saudi Arabia)" do
      assert CodesMap.iso_to_fifa("SAU") == "KSA"
    end

    test "ZAF -> RSA (South Africa)" do
      assert CodesMap.iso_to_fifa("ZAF") == "RSA"
    end

    test "DZA -> ALG (Algeria)" do
      assert CodesMap.iso_to_fifa("DZA") == "ALG"
    end

    test "returns original code for teams where ISO matches FIFA" do
      assert CodesMap.iso_to_fifa("BRA") == "BRA"
      assert CodesMap.iso_to_fifa("FRA") == "FRA"
      assert CodesMap.iso_to_fifa("ARG") == "ARG"
    end
  end

  describe "roundtrip" do
    test "fifa_to_iso then iso_to_fifa returns original for all mapped codes" do
      for {fifa, iso} <- CodesMap.mapping(), fifa != iso do
        assert CodesMap.iso_to_fifa(CodesMap.fifa_to_iso(fifa)) == fifa,
               "Roundtrip failed for FIFA code #{fifa}"

        assert CodesMap.fifa_to_iso(CodesMap.iso_to_fifa(iso)) == iso,
               "Roundtrip failed for ISO code #{iso}"
      end
    end
  end

  describe "mapping/0" do
    test "returns a map" do
      assert is_map(CodesMap.mapping())
    end

    test "contains all expected 2026 WC mapped codes" do
      m = CodesMap.mapping()
      assert Map.has_key?(m, "GER")
      assert Map.has_key?(m, "NED")
      assert Map.has_key?(m, "CRO")
      assert Map.has_key?(m, "URU")
    end
  end

  describe "mapped_fifa_codes/0" do
    test "returns sorted list of FIFA codes that differ from ISO" do
      codes = CodesMap.mapped_fifa_codes()
      assert is_list(codes)
      assert "GER" in codes
      assert "NED" in codes
      assert codes == Enum.sort(codes)
    end

    test "does not include codes where FIFA == ISO" do
      codes = CodesMap.mapped_fifa_codes()
      refute "BRA" in codes
      refute "FRA" in codes
    end
  end
end

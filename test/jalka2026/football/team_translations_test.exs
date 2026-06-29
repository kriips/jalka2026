defmodule Jalka2026.Football.TeamTranslationsTest do
  use ExUnit.Case, async: true

  alias Jalka2026.Football.TeamTranslations

  describe "translate/1" do
    test "translates known team names to Estonian" do
      assert TeamTranslations.translate("Germany") == "Saksamaa"
      assert TeamTranslations.translate("Spain") == "Hispaania"
      assert TeamTranslations.translate("France") == "Prantsusmaa"
      assert TeamTranslations.translate("England") == "Inglismaa"
      assert TeamTranslations.translate("Netherlands") == "Holland"
      assert TeamTranslations.translate("Belgium") == "Belgia"
      assert TeamTranslations.translate("Croatia") == "Horvaatia"
      assert TeamTranslations.translate("Switzerland") == "Šveits"
      assert TeamTranslations.translate("Portugal") == "Portugal"
    end

    test "translates South American teams" do
      assert TeamTranslations.translate("Brazil") == "Brasiilia"
      assert TeamTranslations.translate("Argentina") == "Argentina"
      assert TeamTranslations.translate("Uruguay") == "Uruguay"
      assert TeamTranslations.translate("Colombia") == "Colombia"
    end

    test "translates North American teams" do
      assert TeamTranslations.translate("United States") == "Ameerika Ühendriigid"
      assert TeamTranslations.translate("Mexico") == "Mehhiko"
      assert TeamTranslations.translate("Canada") == "Kanada"
    end

    test "translates Asian teams" do
      assert TeamTranslations.translate("Japan") == "Jaapan"
      assert TeamTranslations.translate("South Korea") == "Lõuna-Korea"
      assert TeamTranslations.translate("Saudi Arabia") == "Saudi Araabia"
      assert TeamTranslations.translate("Iran") == "Iraan"
    end

    test "translates African teams" do
      assert TeamTranslations.translate("Morocco") == "Maroko"
      assert TeamTranslations.translate("Tunisia") == "Tuneesia"
      assert TeamTranslations.translate("Egypt") == "Egiptus"
      assert TeamTranslations.translate("South Africa") == "Lõuna-Aafrika Vabariik"
      assert TeamTranslations.translate("Côte d'Ivoire") == "Elevandiluurannik"
    end

    test "translates Oceania teams" do
      assert TeamTranslations.translate("Australia") == "Austraalia"
      assert TeamTranslations.translate("New Zealand") == "Uus-Meremaa"
    end

    test "returns original name for unknown teams" do
      assert TeamTranslations.translate("Unknown Country") == "Unknown Country"
      assert TeamTranslations.translate("Atlantis") == "Atlantis"
    end

    test "returns nil for nil input" do
      assert TeamTranslations.translate(nil) == nil
    end
  end

  describe "untranslate/1" do
    test "maps an Estonian name back to its English source" do
      assert TeamTranslations.untranslate("Saksamaa") == ["Germany"]
      assert "France" in TeamTranslations.untranslate("Prantsusmaa")
    end

    test "round-trips every translation" do
      for {english, estonian} <- TeamTranslations.translations() do
        assert english in TeamTranslations.untranslate(estonian)
      end
    end

    test "returns an empty list for names that are not translations" do
      assert TeamTranslations.untranslate("Germany") == []
      assert TeamTranslations.untranslate("Unknown Country") == []
    end

    test "returns an empty list for nil" do
      assert TeamTranslations.untranslate(nil) == []
    end
  end

  describe "translations/0" do
    test "returns the full translations map" do
      translations = TeamTranslations.translations()
      assert is_map(translations)
      assert Map.has_key?(translations, "Germany")
      assert Map.has_key?(translations, "Brazil")
      assert translations["Germany"] == "Saksamaa"
    end
  end

  describe "translate_team/1" do
    test "translates a team struct's name" do
      team = %{name: "Germany", code: "GER"}
      translated = TeamTranslations.translate_team(team)
      assert translated.name == "Saksamaa"
      assert translated.code == "GER"
    end

    test "preserves other fields in the team struct" do
      team = %{name: "France", code: "FRA", flag: "fr.png", group: "A"}
      translated = TeamTranslations.translate_team(team)
      assert translated.name == "Prantsusmaa"
      assert translated.code == "FRA"
      assert translated.flag == "fr.png"
      assert translated.group == "A"
    end

    test "returns original name for unknown team" do
      team = %{name: "Unknown", code: "UNK"}
      translated = TeamTranslations.translate_team(team)
      assert translated.name == "Unknown"
    end

    test "returns non-map input as-is" do
      assert TeamTranslations.translate_team(nil) == nil
      assert TeamTranslations.translate_team("string") == "string"
    end
  end
end

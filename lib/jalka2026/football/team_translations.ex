defmodule Jalka2026.Football.TeamTranslations do
  @moduledoc """
  Estonian translations for World Cup 2026 team/country names.
  """

  @translations %{
    # Europe
    "Germany" => "Saksamaa",
    "Spain" => "Hispaania",
    "Portugal" => "Portugal",
    "France" => "Prantsusmaa",
    "England" => "Inglismaa",
    "Netherlands" => "Holland",
    "Belgium" => "Belgia",
    "Croatia" => "Horvaatia",
    "Switzerland" => "Šveits",
    "Austria" => "Austria",
    "Scotland" => "Šotimaa",
    "Norway" => "Norra",
    "Sweden" => "Rootsi",
    "Czechia" => "Tšehhi",
    "Czech Republic" => "Tšehhi",
    "Turkey" => "Türgi",
    "Bosnia-Herzegovina" => "Bosnia ja Hertsegoviina",
    "Bosnia and Herzegovina" => "Bosnia ja Hertsegoviina",
    "Bulgaria" => "Bulgaaria",
    "Denmark" => "Taani",
    "Greece" => "Kreeka",
    "Hungary" => "Ungari",
    "Iceland" => "Island",
    "Israel" => "Iisrael",
    "Italy" => "Itaalia",
    "Northern Ireland" => "Põhja-Iirimaa",
    "Poland" => "Poola",
    "Republic of Ireland" => "Iirimaa",
    "Romania" => "Rumeenia",
    "Russia" => "Venemaa",
    "Serbia" => "Serbia",
    "Serbia and Montenegro" => "Serbia ja Montenegro",
    "Slovakia" => "Slovakkia",
    "Slovenia" => "Sloveenia",
    "Ukraine" => "Ukraina",
    "Wales" => "Wales",

    # Historical European teams
    "Czechoslovakia" => "Tšehhoslovakkia",
    "East Germany" => "Ida-Saksamaa",
    "West Germany" => "Lääne-Saksamaa",
    "Soviet Union" => "Nõukogude Liit",
    "Yugoslavia" => "Jugoslaavia",

    # South America
    "Brazil" => "Brasiilia",
    "Argentina" => "Argentina",
    "Uruguay" => "Uruguay",
    "Colombia" => "Colombia",
    "Ecuador" => "Ecuador",
    "Paraguay" => "Paraguay",
    "Bolivia" => "Boliivia",
    "Chile" => "Tšiili",
    "Peru" => "Peruu",

    # North/Central America & Caribbean
    "United States" => "Ameerika Ühendriigid",
    "Mexico" => "Mehhiko",
    "Canada" => "Kanada",
    "Panama" => "Panama",
    "Haiti" => "Haiti",
    "Curaçao" => "Curaçao",
    "Costa Rica" => "Costa Rica",
    "Cuba" => "Kuuba",
    "El Salvador" => "El Salvador",
    "Honduras" => "Honduras",
    "Jamaica" => "Jamaica",
    "Trinidad and Tobago" => "Trinidad ja Tobago",

    # Asia
    "Japan" => "Jaapan",
    "South Korea" => "Lõuna-Korea",
    "Saudi Arabia" => "Saudi Araabia",
    "Iran" => "Iraan",
    "Qatar" => "Katar",
    "Jordan" => "Jordaania",
    "Uzbekistan" => "Usbekistan",
    "Iraq" => "Iraak",
    "China" => "Hiina",
    "Kuwait" => "Kuveit",
    "North Korea" => "Põhja-Korea",
    "United Arab Emirates" => "Araabia Ühendemiraadid",

    # Historical Asian teams
    "Dutch East Indies" => "Hollandi Ida-India",

    # Africa
    "Morocco" => "Maroko",
    "Senegal" => "Senegal",
    "Tunisia" => "Tuneesia",
    "Algeria" => "Alžeeria",
    "Egypt" => "Egiptus",
    "Ghana" => "Ghana",
    "South Africa" => "Lõuna-Aafrika Vabariik",
    "Côte d'Ivoire" => "Elevandiluurannik",
    "Ivory Coast" => "Elevandiluurannik",
    "Cape Verde Islands" => "Roheneemesaared",
    "Congo DR" => "Kongo DV",
    "Angola" => "Angola",
    "Cameroon" => "Kamerun",
    "Nigeria" => "Nigeeria",
    "Togo" => "Togo",

    # Historical African teams
    "Zaire" => "Zaire",

    # Oceania
    "Australia" => "Austraalia",
    "New Zealand" => "Uus-Meremaa"
  }

  @doc """
  Translates a team/country name to Estonian.
  Returns the original name if no translation is found.

  ## Examples

      iex> TeamTranslations.translate("Germany")
      "Saksamaa"

      iex> TeamTranslations.translate("Unknown Country")
      "Unknown Country"
  """
  def translate(name) when is_binary(name) do
    Map.get(@translations, name, name)
  end

  def translate(nil), do: nil

  @doc """
  Returns the full translations map.
  """
  def translations, do: @translations

  @doc """
  Translates a team struct's name to Estonian.
  Returns the team struct with the name field translated.

  ## Examples

      iex> team = %{name: "Germany", code: "GER"}
      iex> TeamTranslations.translate_team(team)
      %{name: "Saksamaa", code: "GER"}
  """
  def translate_team(%{name: name} = team) when is_map(team) do
    %{team | name: translate(name)}
  end

  def translate_team(team), do: team
end

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

    # South America
    "Brazil" => "Brasiilia",
    "Argentina" => "Argentina",
    "Uruguay" => "Uruguay",
    "Colombia" => "Colombia",
    "Ecuador" => "Ecuador",
    "Paraguay" => "Paraguay",

    # North/Central America & Caribbean
    "United States" => "Ameerika Ühendriigid",
    "Mexico" => "Mehhiko",
    "Canada" => "Kanada",
    "Panama" => "Panama",
    "Haiti" => "Haiti",
    "Curaçao" => "Curaçao",

    # Asia
    "Japan" => "Jaapan",
    "South Korea" => "Lõuna-Korea",
    "Saudi Arabia" => "Saudi Araabia",
    "Iran" => "Iraan",
    "Qatar" => "Katar",
    "Jordan" => "Jordaania",
    "Uzbekistan" => "Usbekistan",

    # Africa
    "Morocco" => "Maroko",
    "Senegal" => "Senegal",
    "Tunisia" => "Tuneesia",
    "Algeria" => "Alžeeria",
    "Egypt" => "Egiptus",
    "Ghana" => "Ghana",
    "South Africa" => "Lõuna-Aafrika Vabariik",
    "Côte d'Ivoire" => "Elevandiluurannik",
    "Cape Verde Islands" => "Roheneemesaared",

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

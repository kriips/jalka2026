defmodule Jalka2026.Football.CodesMap do
  @moduledoc """
  Centralised mapping between FIFA team codes and ISO 3166-1 alpha-3 codes.

  The teams table stores FIFA three-letter abbreviations (TLA) from
  football-data.org (e.g. "GER", "NED", "CRO"), while historical match data
  uses ISO 3166-1 alpha-3 country codes (e.g. "DEU", "NLD", "HRV").

  This module provides bidirectional conversion so that queries against
  historical data always use the correct code system. Teams whose FIFA code
  already matches the ISO code (e.g. "BRA", "FRA", "ARG") are not listed
  in the map — the conversion functions return the input unchanged for those.

  ## Why this exists

  Without an explicit, tested map, queries using FIFA codes silently return
  empty results when the historical data expects ISO codes. This module
  prevents that class of bug and makes it easy to extend the map when new
  teams are added to the competition.
  """

  # FIFA TLA → ISO 3166-1 alpha-3
  # Only codes that actually differ are listed.
  #
  # Sources:
  # - teams.json `tla` vs `area.code` (football-data.org)
  # - historical_matches.json team codes (ISO 3166-1 alpha-3)
  #
  # Current 2026 WC participants whose codes differ:
  @fifa_to_iso %{
    # Germany
    "GER" => "DEU",
    # Netherlands
    "NED" => "NLD",
    # Portugal
    "POR" => "PRT",
    # Switzerland
    "SUI" => "CHE",
    # Croatia
    "CRO" => "HRV",
    # Saudi Arabia
    "KSA" => "SAU",
    # South Africa
    "RSA" => "ZAF",
    # Algeria
    "ALG" => "DZA",
    # Haiti
    "HAI" => "HTI",
    # Paraguay
    "PAR" => "PRY",
    # Uruguay
    "URU" => "URY",
    # Curaçao
    "CUR" => "CUW",
    # Common FIFA codes for teams that may appear in future imports:
    # Chile
    "CHI" => "CHL",
    # Costa Rica
    "CRC" => "CRI",
    # United Arab Emirates
    "UAE" => "ARE",
    # Philippines
    "PHI" => "PHL",
    # Chinese Taipei
    "TPE" => "TWN"
  }

  # Pre-computed reverse map (ISO → FIFA)
  @iso_to_fifa Map.new(@fifa_to_iso, fn {fifa, iso} -> {iso, fifa} end)

  @doc """
  Returns the full FIFA-to-ISO mapping as a plain map.
  """
  @spec mapping() :: %{String.t() => String.t()}
  def mapping, do: @fifa_to_iso

  @doc """
  Convert a FIFA team code to its ISO 3166-1 alpha-3 equivalent.

  Returns the original code unchanged when no mapping exists (the code
  systems already agree for that team).

  ## Examples

      iex> Jalka2026.Football.CodesMap.fifa_to_iso("GER")
      "DEU"

      iex> Jalka2026.Football.CodesMap.fifa_to_iso("BRA")
      "BRA"
  """
  @spec fifa_to_iso(String.t()) :: String.t()
  def fifa_to_iso(code) when is_binary(code) do
    Map.get(@fifa_to_iso, code, code)
  end

  @doc """
  Convert an ISO 3166-1 alpha-3 code back to the FIFA team code.

  Returns the original code unchanged when no mapping exists.

  ## Examples

      iex> Jalka2026.Football.CodesMap.iso_to_fifa("DEU")
      "GER"

      iex> Jalka2026.Football.CodesMap.iso_to_fifa("BRA")
      "BRA"
  """
  @spec iso_to_fifa(String.t()) :: String.t()
  def iso_to_fifa(code) when is_binary(code) do
    Map.get(@iso_to_fifa, code, code)
  end

  @doc """
  List all FIFA codes that have a different ISO equivalent.
  """
  @spec mapped_fifa_codes() :: [String.t()]
  def mapped_fifa_codes do
    @fifa_to_iso
    |> Enum.reject(fn {fifa, iso} -> fifa == iso end)
    |> Enum.map(fn {fifa, _} -> fifa end)
    |> Enum.sort()
  end
end

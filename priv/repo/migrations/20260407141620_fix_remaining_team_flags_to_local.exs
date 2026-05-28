defmodule Jalka2026.Repo.Migrations.FixRemainingTeamFlagsToLocal do
  use Ecto.Migration

  # Teams missed by the previous migration (20260206104343) due to
  # name mismatches or missing entries. Updates any team still pointing
  # at an external crests.football-data.org URL to use the local SVG flag.
  @fixes %{
    "Sweden" => "/images/flags/se.svg",
    "Czechia" => "/images/flags/cz.svg",
    "Turkey" => "/images/flags/tr.svg",
    "Bosnia-Herzegovina" => "/images/flags/ba.svg",
    "Congo DR" => "/images/flags/cd.svg",
    "Ivory Coast" => "/images/flags/ci.svg",
    "Iraq" => "/images/flags/iq.svg"
  }

  def up do
    Enum.each(@fixes, fn {name, flag_path} ->
      execute(
        "UPDATE teams SET flag = '#{flag_path}' WHERE name = '#{escape_sql(name)}' AND flag LIKE 'http%'"
      )
    end)
  end

  def down do
    :ok
  end

  defp escape_sql(string) do
    String.replace(string, "'", "''")
  end
end

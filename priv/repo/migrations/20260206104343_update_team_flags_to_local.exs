defmodule Jalka2026.Repo.Migrations.UpdateTeamFlagsToLocal do
  use Ecto.Migration

  # Map team names to ISO 2-letter country codes for local flag files
  @team_name_to_flag %{
    "Uruguay" => "/images/flags/uy.svg",
    "Germany" => "/images/flags/de.svg",
    "Spain" => "/images/flags/es.svg",
    "Paraguay" => "/images/flags/py.svg",
    "Argentina" => "/images/flags/ar.svg",
    "Ghana" => "/images/flags/gh.svg",
    "Brazil" => "/images/flags/br.svg",
    "Portugal" => "/images/flags/pt.svg",
    "Japan" => "/images/flags/jp.svg",
    "Mexico" => "/images/flags/mx.svg",
    "England" => "/images/flags/gb-eng.svg",
    "United States" => "/images/flags/us.svg",
    "South Korea" => "/images/flags/kr.svg",
    "France" => "/images/flags/fr.svg",
    "South Africa" => "/images/flags/za.svg",
    "Algeria" => "/images/flags/dz.svg",
    "Australia" => "/images/flags/au.svg",
    "New Zealand" => "/images/flags/nz.svg",
    "Switzerland" => "/images/flags/ch.svg",
    "Ecuador" => "/images/flags/ec.svg",
    "Croatia" => "/images/flags/hr.svg",
    "Saudi Arabia" => "/images/flags/sa.svg",
    "Tunisia" => "/images/flags/tn.svg",
    "Senegal" => "/images/flags/sn.svg",
    "Belgium" => "/images/flags/be.svg",
    "Morocco" => "/images/flags/ma.svg",
    "Austria" => "/images/flags/at.svg",
    "Colombia" => "/images/flags/co.svg",
    "Egypt" => "/images/flags/eg.svg",
    "Canada" => "/images/flags/ca.svg",
    "Haiti" => "/images/flags/ht.svg",
    "Iran" => "/images/flags/ir.svg",
    "Panama" => "/images/flags/pa.svg",
    "Cape Verde Islands" => "/images/flags/cv.svg",
    "Côte d'Ivoire" => "/images/flags/ci.svg",
    "Qatar" => "/images/flags/qa.svg",
    "Jordan" => "/images/flags/jo.svg",
    "Uzbekistan" => "/images/flags/uz.svg",
    "Netherlands" => "/images/flags/nl.svg",
    "Norway" => "/images/flags/no.svg",
    "Scotland" => "/images/flags/gb-sct.svg",
    "Curaçao" => "/images/flags/cw.svg"
  }

  def up do
    Enum.each(@team_name_to_flag, fn {name, flag_path} ->
      execute("UPDATE teams SET flag = '#{flag_path}' WHERE name = '#{escape_sql(name)}'")
    end)
  end

  def down do
    # Revert to empty flags (we can't restore external URLs)
    execute("UPDATE teams SET flag = NULL")
  end

  defp escape_sql(string) do
    String.replace(string, "'", "''")
  end
end

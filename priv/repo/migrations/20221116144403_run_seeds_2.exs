defmodule Jalka2026.Repo.Migrations.RunSeeds2 do
  use Ecto.Migration

  def change do
    Jalka2026.Seed.seed2()
  end
end

defmodule Jalka2026.Repo.Migrations.CreateFeedConfiguration do
  use Ecto.Migration

  def change do
    create table(:feed_configuration) do
      add :feed_enabled, :boolean, default: false, null: false
      add :polling_interval_seconds, :integer, default: 120, null: false
      add :max_retries, :integer, default: 5, null: false
      add :degraded_mode, :boolean, default: false, null: false
      add :api_key, :string
      add :feed_url, :string
      timestamps(type: :utc_datetime)
    end

    create constraint(:feed_configuration, :singleton_config, check: "id = 1")
  end
end

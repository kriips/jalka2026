alias Jalka2026.Repo

# Ensure singleton feed configuration exists
unless Repo.get_by(%{__struct__: Ecto.Schema.Metadata, source: "feed_configuration"}, id: 1) do
  Repo.query!("INSERT INTO feed_configuration (id, feed_enabled, polling_interval_seconds, max_retries, degraded_mode, inserted_at, updated_at) VALUES (1, false, 120, 5, false, NOW(), NOW())")
end

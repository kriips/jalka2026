import Config

feed_enabled = System.get_env("FEED_ENABLED", "false") == "true"
feed_url = System.get_env("FEED_URL")
feed_api_key = System.get_env("FEED_API_KEY")
polling_interval = System.get_env("POLLING_INTERVAL_SECONDS", "120") |> String.to_integer()
max_retries = System.get_env("MAX_RETRIES", "5") |> String.to_integer()
backoff_base_ms = System.get_env("BACKOFF_BASE_MS", "500") |> String.to_integer()
backoff_jitter_ms = System.get_env("BACKOFF_JITTER_MS", "250") |> String.to_integer()

config :jalka2026, Jalka2026.FeedConfig,
  enabled: feed_enabled,
  url: feed_url,
  api_key: feed_api_key,
  polling_interval_seconds: polling_interval,
  max_retries: max_retries,
  backoff_base_ms: backoff_base_ms,
  backoff_jitter_ms: backoff_jitter_ms

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL env var is required in production"

  config :jalka2026, Jalka2026.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))
end

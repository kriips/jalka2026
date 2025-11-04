import Config

config :jalka2026, Jalka2026.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", ""),
  hostname: System.get_env("PGHOST", "localhost"),
  database: "jalka2026_test",
  port: String.to_integer(System.get_env("PGPORT", "5432")),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5

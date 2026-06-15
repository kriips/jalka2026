import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :jalka2026, Jalka2026.Repo,
  username: "postgres",
  password: "postgres",
  database: "jalka2026_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :jalka2026, Jalka2026Web.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

config :jalka2026, :environment, :test

# Tests build small fixture datasets, so don't require complete group
# predictions for leaderboard inclusion (overridden per-test where the
# filter itself is under test).
config :jalka2026, :leaderboard_required_predictions, 0

# Jalka2026

World Cup 2026 prediction game built with Phoenix 1.7 and LiveView 1.0.

Live at [jalka.eys.ee](https://jalka.eys.ee)

## Prerequisites

- Elixir ~> 1.17
- Erlang/OTP 28+
- PostgreSQL 16+

## Local Development

### Initial Setup

```bash
# Install dependencies
mix deps.get

# Create database, run migrations, and seed data
mix ecto.setup

# Start the server
mix phx.server
```

The app will be available at [localhost:4000](http://localhost:4000).

esbuild handles asset bundling automatically during development.

### Environment Variables

The dev environment loads variables from a `.env` file in the project root (via `dotenv_parser`). Required variables:

| Variable | Description |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `SECRET_KEY_BASE` | Phoenix secret key |
| `SIGNING_SALT` | LiveView signing salt |

Optional:

| Variable | Description |
|---|---|
| `COMPETITION_ID` | Active tournament identifier (default: `wc-2026`) |

### Useful Mix Aliases

```bash
mix setup          # deps.get + ecto.setup
mix ecto.reset     # Drop, create, migrate, and seed the database
```

## Testing

```bash
# Run all tests
mix test

# Run a specific test file
mix test test/jalka2026/football_test.exs

# Run a specific test by line number
mix test test/jalka2026/football_test.exs:42
```

The `mix test` alias automatically creates and migrates the test database before running.

### Test Coverage (Coveralls)

The project uses [ExCoveralls](https://github.com/parroty/excoveralls) for test coverage.

```bash
# Generate coverage report (HTML)
mix coveralls.html
# Report is written to cover/excoveralls.html

# Console summary
mix coveralls

# JSON output (for CI integration)
mix coveralls.json
```

## Code Quality

### Credo (Linter)

```bash
# Full analysis
mix credo --strict

# Check only new issues vs master (used in CI for PRs)
mix credo diff master --strict
```

Configuration is in `.credo.exs`.

### Dialyzer (Static Type Analysis)

```bash
# Run dialyzer (first run builds the PLT, which takes a while)
mix dialyzer
```

PLT files are cached in `priv/plts/` and ignored by git. Known false positives are listed in `.dialyzer_ignore.exs`.

### Formatter

```bash
mix format
```

## CI

GitHub Actions runs on every push and PR to `master` (`.github/workflows/ci.yml`):

- **Credo** -- linting (`credo diff` on PRs, full check on master)
- **Dialyzer** -- static type analysis
- **Tests** -- `mix test` against PostgreSQL 16

## Deploying to Fly.io

The app is deployed to [Fly.io](https://fly.io) as `jalka2026` in the `arn` (Stockholm) region.

### Deploy

```bash
fly deploy
```

This builds a Docker image (see `Dockerfile`), pushes it to Fly, and runs the release migration command (`/app/bin/migrate`) before starting the new version.

### Useful Fly Commands

```bash
# Check app status
fly status

# View logs
fly logs

# Open a remote IEx console
fly ssh console --command "/app/bin/jalka2026 remote"

# Run migrations manually
fly ssh console --command "/app/bin/migrate"

# Set environment variables (secrets)
fly secrets set SECRET_KEY_BASE=... SIGNING_SALT=...

# Scale resources
fly scale vm shared-cpu-1x --memory 1024
```

### Production Environment Variables

Set via `fly secrets set`:

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | Yes | PostgreSQL connection string |
| `SECRET_KEY_BASE` | Yes | Phoenix secret key |
| `SIGNING_SALT` | Yes | LiveView signing salt |
| `FLY_APP_NAME` | Auto | Set automatically by Fly |
| `PORT` | Auto | Set in `fly.toml` (8080) |
| `COMPETITION_ID` | No | Tournament ID (default: `wc-2026`) |
| `EMAIL_FROM` | No | Sender address for notifications |
| `EMAIL_NOTIFICATIONS_ENABLED` | No | Set to `true` to enable email notifications |

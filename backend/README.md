# Backend (Phoenix) for Jalka2026

Initial scaffolding for leaderboard feed feature.

## Mix Aliases
- `full.rescore` placeholder prints TODO (will be replaced in T060).

## Migrations Added
- ingestion_events
- conflict_records
- scoring_events
- feed_configuration (singleton)

## Configuration
Runtime config reads environment variables for feed ingestion parameters.

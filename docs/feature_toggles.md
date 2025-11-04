# Feature Toggles

## Feed Ingestion Toggle
- Primary: environment variable `FEED_ENABLED` (read at runtime start in `runtime.exs`).
- Secondary: database `feed_configuration.feed_enabled` column allowing dynamic enable/disable without restart.

### Precedence
1. If DB row id=1 exists and has `feed_enabled=true`, ingestion runs (unless environment variable explicitly forces off via `FEED_ENABLED=false`).
2. Environment variable `FEED_ENABLED=true` with no DB row will start ingestion in enabled mode but recommend seeding configuration (see seeds).
3. Setting `degraded_mode=true` in configuration will pause polling retries after threshold breaches (implementation task later).

### Changing at Runtime
- Admin UI will flip DB column (future task US5).
- For emergency disable: export `FEED_ENABLED=false` and restart release.

### Validation Rules (planned in configuration schema changeset)
- `polling_interval_seconds >= 30`
- `max_retries BETWEEN 1 AND 10`

## Future Toggles
- Full rescore gating (e.g. require maintenance flag)
- Conflict auto-archive threshold

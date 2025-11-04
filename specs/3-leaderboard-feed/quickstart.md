# Quickstart: Leaderboard Auto-Recalculation & External Results Feed

## Prerequisites
- Existing application running (Phoenix server)
- Environment variables set: FEED_ENABLED=false|true, FEED_API_KEY (if enabled), FEED_URL, POLLING_INTERVAL_SECONDS (optional), MAX_RETRIES (optional)

## Enable Feed Ingestion
1. Set FEED_ENABLED=true
2. Provide FEED_API_KEY and FEED_URL
3. (Optional) Set POLLING_INTERVAL_SECONDS (>=30, default 120)
4. Restart application to start polling worker

## Manual Result Entry (Fallback)
- Admin enters match score; triggers incremental scoring automatically.
- If feed in degraded mode (after threshold failures) manual scoring unaffected.

## Conflict Resolution Flow
1. Conflict appears on dashboard
2. Admin Approve → overwrite + incremental/full scoring as required
3. Admin Reject → resolution stored; no overwrite

## Rescore Operations
- Full rescore: Mix task or /admin/scoring/rescore endpoint.
- Incremental rescore: /admin/scoring/incremental/{match_id}.

## Simulation (Non-Production)
- Use /admin/ingest/simulate to submit test payloads.

## Environment Variable Reference
| Var | Purpose | Default |
|-----|---------|---------|
| FEED_ENABLED | Toggle ingestion | false |
| FEED_API_KEY | Auth key header | (required if enabled) |
| FEED_URL | Feed endpoint | (required if enabled) |
| POLLING_INTERVAL_SECONDS | Poll interval | 120 |
| MAX_RETRIES | Retry attempts | 5 |

## Troubleshooting
- Repeated failures: check FEED_URL & API key.
- No updates: verify FEED_ENABLED and polling interval validity (>=30).
- High latency: inspect logs for scoring duration.

Status: QUICKSTART DRAFT
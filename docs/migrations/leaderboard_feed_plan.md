# Migration Plan: Leaderboard Feed (T011-T015)

## Overview
Foundational tables for ingestion and scoring metadata. Ordered to reduce dependency coupling.

## Tables
1. ingestion_events
   - id (bigserial)
   - external_match_id (varchar)
   - event_type (enum: fetched|parsed|ingested|error|noop)
   - status (enum: success|error|noop)
   - message (text, nullable)
   - payload_hash (varchar, dedupe detection)
   - latency_ms (int, nullable)
   - inserted_at, updated_at (timestamps)
   - index: (external_match_id, status)
   - index: payload_hash unique partial where status='success'

2. conflict_records
   - id
   - external_match_id
   - feed_score_home (int)
   - feed_score_away (int)
   - local_score_home (int)
   - local_score_away (int)
   - resolved_at (timestamp nullable)
   - resolution (enum: approved|rejected|null)
   - inserted_at, updated_at
   - index: external_match_id unique where resolved_at IS NULL

3. scoring_events
   - id
   - match_id (fk matches.id)
   - mode (enum: incremental|full)
   - affected_predictions_count (int)
   - latency_ms (int)
   - started_at (timestamp)
   - completed_at (timestamp)
   - inserted_at, updated_at
   - index: match_id

4. feed_configuration
   - id (singleton: 1)
   - feed_enabled (boolean, default false)
   - polling_interval_seconds (int default 120)
   - max_retries (int default 5)
   - degraded_mode (boolean default false)
   - api_key (varchar nullable)
   - feed_url (varchar nullable)
   - inserted_at, updated_at

5. Index additions (performance polish)
   - ingestion_events: index on inserted_at desc
   - scoring_events: composite index (mode, inserted_at)

## Order
Apply 1→2→3→4 then 5 indexes (can fold into earlier migrations except latency_ms addition if deferred).

## Notes
- Use enums via Ecto string values (no PostgreSQL enum needed yet for agility).
- Singleton feed_configuration enforced by unique constraint id=1 and maybe check constraint.
- Future: Add partitioning on ingestion_events if volume grows.

## Acceptance
- Migrations run clean on empty DB.
- Rollback leaves schema consistent (drop tables reverse order).

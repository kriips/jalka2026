# Data Model: Leaderboard Auto-Recalculation & External Results Feed

## Entities

### ExternalResult (Transient Validation, not persisted)
Fields: match_id:string, home_score:int, away_score:int, status:enum(completed|scheduled|canceled), completed_at:utc_datetime.
Used for: validating feed payload before applying.

### IngestionEvent
Fields: id (UUID), match_id (UUID nullable if not parsed), event_type:enum(poll|ingest|conflict|retry|abort|no-op), status:enum(success|error|conflict|ignored), payload_hash:string, attempt:int, duration_ms:int, inserted_at:utc_datetime.
Indexes: (match_id), (event_type), (status), (inserted_at DESC).

### ConflictRecord
Fields: id (UUID), match_id (UUID), existing_home:int, existing_away:int, feed_home:int, feed_away:int, detected_at:utc_datetime, resolved_at:utc_datetime nullable, resolution:enum(approved|rejected|null).
Constraints: resolution NULL until admin action; resolved_at must NOT NULL when resolution != NULL.
Indexes: (match_id), (resolution), (detected_at DESC).

### ScoringEvent
Fields: id (UUID), match_id (UUID), event_trigger:enum(manual|feed|correction|full-rescore), affected_user_count:int, latency_ms:int, mode:enum(incremental|full), completed_at:utc_datetime.
Indexes: (match_id), (event_trigger), (completed_at DESC).

### Configuration (Singleton Row)
Fields: id:smallint (always 1), feed_enabled:boolean, polling_interval_seconds:int, max_retries:int, api_endpoint:string, auth_secret_ref:string, degraded_mode:boolean.
Validation: polling_interval_seconds >=30; fallback to 120 if invalid; max_retries 1..10; api_endpoint URL format.

## Relationships
ConflictRecord belongs_to Match.
ScoringEvent belongs_to Match.
IngestionEvent optionally references Match after parsing.
Configuration referenced by ingestion worker on start.

## State Transitions
ConflictRecord: pending (resolution NULL) → approved|rejected (sets resolved_at).
Configuration: degraded_mode toggled true after threshold; set false after successful ingest.

## Validation Rules
- ExternalResult scores >=0.
- Duplicate identical final score ingest → produce no-op IngestionEvent.
- Conflict requires differing home OR away score.
- Approved conflict triggers overwrite then ScoringEvent.
- polling_interval_seconds: if <30 revert to 120.

## Edge Cases
- Missing match_id in feed payload → log ingest error, no scoring.
- Canceled match after scoring → rollback logic (handled outside this model; mark scoring event rollback separately if needed).

## Performance Considerations
Indexes support recent event queries and conflict dashboards; event tables expected size small (< few thousand rows).

Status: DATA MODEL DRAFT
# Research & Decisions: Leaderboard Auto-Recalculation & External Results Feed

## 1. External Feed Protocol
Decision: JSON over HTTPS with fields {match_id:string, home_score:int, away_score:int, status:"completed"|"scheduled"|"canceled", completed_at:ISO8601}.  
Rationale: Simple, widely supported; minimal parsing overhead.  
Alternatives: XML (verbose), GraphQL (complex), CSV (less structured).

## 2. Authentication Method
Decision: API key via `X-Feed-Api-Key` header.  
Rationale: Simplicity; avoids token refresh complexities; acceptable for single provider.  
Alternatives: Bearer token (requires refresh flow), mTLS (higher ops complexity).

## 3. Retry & Backoff Parameters
Decision: base_delay = 500ms, multiplier = 2.0, max_attempts = 5, jitter ±100ms.  
Rationale: Limits time-to-fail (~7.5s worst-case) while not hammering provider.  
Alternatives: Fixed delay (risk burst), larger max attempts (slower fallback), no jitter (thundering herd risk).

## 4. Conflict Workflow UX
Decision: Conflict row rendered with approve/reject buttons; approve triggers overwrite + scoring; reject closes conflict.  
Rationale: Minimal friction, explicit decision path; matches clarified requirement.  
Alternatives: Bulk actions (deferred), auto-accept heuristic (rejected for correctness risk).

## 5. Incremental vs Full Rescore Boundary
Decision: Targeted rescore on single result corrections; full rescore only when playoff advancement corrections OR scoring logic version bump occurs.  
Rationale: Resource efficiency; preserves determinism.  
Alternatives: Always full rescore (overkill), scheduled daily full rescore (unnecessary).

## 6. HTTP Client Choice
Decision: Finch (modern, pool managed).  
Rationale: Good performance, straightforward supervision.  
Alternatives: :httpc (older), Hackney (additional dependency, heavier).

## 7. Payload Validation Strategy
Decision: Pattern match + Ecto embedded schema for ExternalResult, reject if required fields missing or non-integer scores.  
Rationale: Leverages existing validation tooling; explicit errors.  
Alternatives: Manual map checks (more error-prone), JSON schema lib (extra dependency).

## 8. Failure Threshold for Fallback
Decision: Enter degraded manual mode after 5 consecutive failed ingestion attempts; resume normal after one success.  
Rationale: Clear threshold balances resiliency and noise.  
Alternatives: Adaptive threshold (complex), immediate fallback (too reactive).

## 9. Safe Shutdown Handling
Decision: On application stop, polling worker sets current attempt status to aborted if mid-request.  
Rationale: Maintains audit completeness.  
Alternatives: Ignore in-flight (loses visibility).

## 10. Logging Structure
Decision: Log ingestion events as JSON: {event:"ingest", match_id, status, attempt, duration_ms}.  
Rationale: Consistent parseable structure for future metrics.  
Alternatives: Unstructured plaintext (less machine-friendly).

All unknowns resolved; no remaining NEEDS CLARIFICATION markers.

Status: RESEARCH COMPLETE
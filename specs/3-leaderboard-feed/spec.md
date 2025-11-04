# Feature Specification: Leaderboard Auto-Recalculation & External Results Feed

## 1. Feature Summary
Automate leaderboard updates whenever new match results are recorded and optionally ingest official match results from an external feed to reduce manual admin work and increase accuracy.

## 2. Problem Statement
Manual result entry delays scoring updates and increases risk of human error. Participants expect timely leaderboard changes after matches finish. An external results feed may streamline operations, but integration needs clear reliability and conflict handling.

## 3. Goals
- Auto-trigger scoring + leaderboard recalculation immediately after each result.
- Support optional external feed ingestion for match final scores.
- Ensure deterministic, transparent recalculation when corrections occur.
- Provide audit trail for all score updates.
- Minimize latency between result availability and leaderboard update.

## 4. Non-Goals
- Real-time minute-by-minute match stats.
- Predictive modeling or projections.
- Multi-provider feed aggregation.
- Historical data backfill beyond tournament scope.

## 5. Actors
- Participant: Views up-to-date leaderboard and personal scores.
- Admin: Manually enters or corrects results; configures feed integration.
- System (Ingestion Worker): Polls/receives external feed updates; triggers scoring.

## 6. User Scenarios
1. Admin enters a match final score → leaderboard updates within seconds.
2. External feed posts a completed match result → system ingests, scores, updates leaderboard.
3. Admin corrects a previously entered erroneous result → system performs full or targeted rescore.
4. Feed provides conflicting data (different score than stored) → system flags conflict and requires admin confirmation before overwrite.
5. Participant refreshes leaderboard page shortly after match completion and sees updated rankings.
6. Ingestion temporarily fails (network error) → system retries; admin sees warning.
7. Feed disabled (manual-only mode) → no polling occurs; manual results still trigger recalculation.

## 7. Functional Requirements
FR1 System must automatically invoke scoring and leaderboard update when a match status changes to completed (manual or feed).
FR2 Recalculation must update affected users' group and playoff points (only users with predictions for that match unless correction requires full pass).
FR3 Feed ingestion module can be toggled on/off by admin configuration.
FR4 When feed result differs from stored result (same match) system logs a conflict event and enters a "pending conflict" state; scoring is not altered. Admin must explicitly approve (overwrite with feed score) or reject (retain existing score) each conflict before any overwrite or rescoring occurs. No automatic resolution.
FR5 Ingestion supports polling interval configuration; default polling_interval_seconds = 120 (fallback if invalid or unset). Negative or zero values revert to 120.
FR6 Ingestion retries transient failures with exponential backoff (max attempts configurable).
FR7 All ingestion actions logged with timestamp, match id, source, status (success|conflict|error|ignored).
FR8 Manual corrections trigger targeted rescore (single match scope) unless the correction affects playoff advancement dependencies or a scoring logic version change has been flagged; those cases require full rescore.
FR9 System must expose an audit history for each match (events: created, scored, corrected, ingested, conflicted).
FR10 Leaderboard update duration target <5s processing for incremental scoring (excluding feed latency).
FR11 Provide Mix task to run full rescore irrespective of feed state.
FR12 Provide Mix task to simulate feed ingestion for testing (disabled in production).
FR13 Admin can view feed status dashboard (last fetch time, last success, pending conflicts count).
FR14 Conflict must be resolvable by admin via approve (overwrite with feed) or reject (keep manual).
FR15 Latency metric (time from result availability to leaderboard generation) recorded.
FR16 Idempotent processing: re-ingesting same final score does not duplicate events or alter scoring.
FR17 System prevents scoring if match already scored with identical final scores (no-op path logged).
FR18 Support safe shutdown: incomplete ingestion attempts marked aborted for observability.
FR19 Feed integration can be configured with API key or URL placeholder (secure storage of secrets).
FR20 Degraded mode (feed unreachable) automatically falls back to manual entry without blocking scoring.

## 8. Success Criteria
SC1 Leaderboard updates visible to users within 30 seconds of final score availability (manual or feed) in 95% of cases.
SC2 Conflict events resolved by admin within 10 minutes median during active periods.
SC3 No duplicate scoring events for the same unchanged result across ≥99% of ingestions.
SC4 Feed downtime does not prevent manual result entry or scoring (0 blocking incidents).
SC5 Full rescore Mix task completes under 2 minutes for dataset ≤5k users.
SC6 Audit history available for 100% of completed matches.
SC7 Latency metrics accessible for all scoring events.
SC8 Error rate of ingestion attempts <5% excluding external provider outages.

## 9. Key Entities
Match (extended for audit timeline events).  
ExternalResult: match_id, home_score, away_score, source_timestamp, provider_ref.  
IngestionEvent: id, match_id, event_type (poll|ingest|conflict|retry|abort|no-op), status, payload_hash, attempted_at, duration_ms.  
ScoringEvent: id, match_id, event_trigger (manual|feed|correction|full-rescore), affected_user_count, latency_ms, completed_at, mode (incremental|full).  
ConflictRecord: id, match_id, existing_home, existing_away, feed_home, feed_away, detected_at, resolved_at, resolution (approved|rejected|null).  
LeaderboardSnapshot (existing, reused).  
Configuration: feed_enabled, polling_interval_seconds, max_retries, api_endpoint, auth_secret_ref.

## 10. Edge Cases
- Feed supplies partial data (missing score) → ignore event, log incomplete.
- Feed sends duplicate score with earlier timestamp → treat as idempotent no-op.
- Manual correction after feed ingestion → scoring recalculates and audit chain preserves both.
- Conflicting result after admin resolved conflict → new conflict reopens case.
- Polling interval misconfigured (0 or negative) → revert to default.
- External provider outage over extended period → switch to degraded mode logging.
- Match canceled after feed previously reported a score → cancel event triggers rollback scoring for that match.

## 11. Assumptions
A1 Single feed provider; no multi-source merging.  
A2 Polling approach (webhook integration deferred).  
A3 Incremental scoring suffices unless correction spans playoff dependencies.  
A4 Admin UI already exists for manual result entry (extension only).  
A5 Secure secrets storage available (environment variables).  
A6 Latency measurement starts when result persisted (not when match actually ends).  
A7 Conflict detection strictly by differing home or away score values.  

## 12. Dependencies
- Existing scoring & leaderboard modules.  
- Time synchronization (UTC).  
- Secure storage for feed credentials.  
- Logging infrastructure.  

## 13. Risks
- Feed unreliability causing false conflicts.  
- Misconfiguration of polling interval leading to rate limits.  
- Performance degradation with frequent full rescoring.  

## 14. Out of Scope
- Real-time push updates (websockets from provider).  
- Multi-tournament support.  
- Predictive analytics based on partial in-progress data.  

## 15. Open Questions
See clarification markers.

## 16. Clarification Markers
(All previous markers resolved.)

## Clarifications
### Session 2025-11-04
- Q: Conflict resolution flow specifics → A: Explicit per-conflict admin approve/reject required before overwrite or rescoring; no automatic acceptance.
- Q: Polling interval default value → A: 120 seconds default; invalid (≤0) values fallback to 120.
- Q: Criteria for choosing full rescore vs targeted → A: Full rescore only on playoff advancement corrections or scoring logic version change; all other corrections are targeted.

## 17. Acceptance Criteria (Samples)
AC1 Recording a manual match final score triggers incremental scoring and updates leaderboard snapshot.  
AC2 Ingesting identical score twice yields one scoring event and one no-op ingestion event.  
AC3 Conflict detection prevents automatic overwrite and logs conflict record.  
AC4 Approving a conflict overwrites existing score and re-triggers scoring.  
AC5 Rejecting a conflict preserves existing score and marks conflict resolved.  
AC6 Polling interval mis-set to negative uses default fallback.  
AC7 Full rescore task recalculates all matches and updates leaderboard snapshot.  
AC8 Latency metric stored for each scoring event.  
AC9 Degraded mode still allows manual scoring without errors.

## 18. Monitoring & Evaluation
Metrics: ingestion_success_count, ingestion_conflict_count, ingestion_error_rate, scoring_latency_ms, incremental_vs_full_ratio, unresolved_conflicts, feed_uptime_percent.

## 19. Glossary
Conflict: Discrepancy between stored score and feed-provided score.  
Incremental Scoring: Updating only affected predictions/users.  
Full Rescore: Re-evaluating all predictions and leaderboard from scratch.  
Degraded Mode: Operating without feed ingestion while allowing manual updates.

## 20. Privacy
No additional personal data stored; feed data pertains to matches only.

Status: SPEC DRAFT
Readiness: Awaiting clarification responses.

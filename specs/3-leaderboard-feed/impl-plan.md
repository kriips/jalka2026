# Implementation Plan: Leaderboard Auto-Recalculation & External Results Feed

## 1. Technical Context
Stack Alignment: Elixir, Phoenix, LiveView (existing app). Feed ingestion as OTP process (GenServer or Task.Supervisor). No staging environment per constitution; local + Fly.io.

Components:
- Ingestion Supervisor: starts polling worker if feed_enabled.
- Polling Worker: executes interval loop; fetches external feed endpoint.
- Conflict Resolver: persists ConflictRecord; awaits admin action.
- Scoring Orchestrator (reuse existing scoring context) invoked on valid new or corrected results.
- Leaderboard Updater: incremental update; full rescore path.

Data Stores: PostgreSQL (existing). No additional cache layer initially.

Unknowns (to research):
- NEEDS CLARIFICATION: External feed protocol format (assume JSON over HTTPS).
- NEEDS CLARIFICATION: Authentication method (API key header vs bearer token).
- NEEDS CLARIFICATION: Recommended retry/backoff parameters (max attempts, base delay).

Performance Targets:
- Incremental scoring <5s per result.
- Polling overhead negligible (<100ms typical fetch).

Reliability:
- Retry transient HTTP failures.
- Fallback manual mode when consecutive failures exceed threshold.

Security:
- Secrets via env vars (FEED_API_KEY, FEED_URL, FEED_ENABLED, POLLING_INTERVAL_SECONDS).
- Validate payload schema; ignore unexpected fields.

Observability:
- Structured logs for ingestion events and scoring latency.
- Metrics counters (future) – out of initial scope.

Deployment:
- Single Fly.io process; no separate worker dyno initially.

## 2. Constitution Check (Initial)
Test-First: Plan includes test coverage for ingestion, conflict, scoring triggers.
CLI Scope: Only batch tasks (full rescore) preserved; aligns with constraint.
Observability: Structured logging present.
Security: Secrets not committed; env usage. Validation stated.
Simplicity: Single worker, no premature multi-process.
Result: PASS (no violations).

## 3. Phase 0: Research Outline
Research tasks:
1. External feed protocol: confirm JSON fields set {match_id, home_score, away_score, status, completed_at}.
2. Auth method: compare API key header vs bearer token.
3. Retry/backoff parameters: choose base_delay ms, multiplier, max_attempts.
4. Conflict workflow UX: ensure minimal admin friction (already clarified per-conflict approval).
5. Incremental vs full rescore algorithm boundaries (already clarified).

## 4. Research Consolidation (See research.md)
Will finalize decisions and remove NEEDS CLARIFICATION markers.

## 5. Phase 1: Design & Contracts
Artifacts planned:
- data-model.md: Entities & relationships.
- contracts/openapi.yaml: Admin endpoints (list conflicts, resolve conflict, feed status, toggle feed).
- quickstart.md: Environment vars, enabling feed, running rescore.

## 6. Phase 1 Agent Context Update
Add ingestion component description, configuration keys, conflict resolution rule.

## 7. Phase 2 (High-Level Build Plan)
Implementation steps (to be expanded into tasks):
1. Migrations for new tables.
2. Ingestion worker module + supervisor registration.
3. HTTP client wrapper (simple :hackney or Finch) with retry/backoff.
4. Conflict detection & persistence.
5. Trigger scoring orchestration.
6. Leaderboard incremental update reuse.
7. Admin LiveView: conflict dashboard & feed status.
8. Mix tasks: full rescore, simulate ingestion.
9. Tests (unit + integration) for ingestion cycles and conflict resolution flows.

## 8. Post-Design Constitution Check
Will verify no added complexity (e.g., avoid multi-provider). Expect PASS.

## 9. Risks & Mitigations
- Feed instability → manual fallback detection on consecutive failures.
- Over-polling → default interval 120s with validation.
- Large corrections → full rescore path documented.
- Race on approval vs new feed update → lock conflict row during resolution transaction.

## 10. Open Items
All unknowns slated for resolution in research.md. No additional clarifications required afterwards.

Status: PLAN DRAFT
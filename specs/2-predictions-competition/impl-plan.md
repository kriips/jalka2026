# Implementation Plan: World Cup 2026 Prediction Competition

## 1. Technical Context
Stack: Elixir (OTP), Phoenix, LiveView, Tailwind CSS, PostgreSQL, Fly.io deployment.
Authentication: Email + password (session cookies).
Authorization: Simple role flag (admin boolean).
Data volume (est.): <5k users, predictions <300k rows.
Concurrency: Low write contention; scoring after result updates.
Time & Locking: UTC; per-match lock at kickoff; global playoff picks lock at tournament kickoff.
Scoring: Outcome (1) + exact (1); playoff R16=1, QF=3, SF=5, Finalist=6, Champion=8 (cumulative).
Email verification: Skipped MVP.
Deployment: Single Fly.io app initially.
Caching: Not critical; rely on DB indexes.
Leaderboard updates: Incremental update & snapshot table.
Observability: Logger metadata (module, user_id); structured scoring events.
Security: Rate limit auth attempts (ETS counter), Argon2 hashing.
Styling: Palette (blue primary, black accents, white background) via Tailwind config.
Tests: ExUnit + factories; coverage target 60% enforced CI.

Unknowns resolved:
- Password hashing: Argon2.
- Leaderboard strategy: incremental.
- Scaling: single app initially.

## 2. Constitution Alignment
All principles satisfied (test-first, modular contexts, LiveView, Tailwind, locks, logging). No conflicts.

## 3. Phase Breakdown
Phase 1 Setup → Phase 2 Foundational DB & schemas → US1 Auth → US2 Group Predictions → US3 Playoff Picks → US4 Scoring/Leaderboard → US5 Admin Tools → US6 Landing Page → Polish.

## 4. Contexts
Accounts, Teams, Matches, Predictions, Playoffs, Scoring, Leaderboard.

## 5. Key Design Decisions
Pure scoring functions; incremental leaderboard; single global playoff lock; CLI only for batch tasks; arrays for stage picks.

## 6. Quality Gates
CI stages: format, credo, compile (warnings-as-errors), tests, coverage threshold.

## 7. Edge Case Handling
Reschedule updates kickoff; canceled matches yield zero scoring; advancement correction triggers rescore; champion cumulative scoring.

## 8. Deployment Flow
Build release → run tests in image → fly deploy → run migrations (release task) → health checks.

## 9. Observability Minimum
Structured log on scoring with fields: event_type, match_id, user_count_changed, duration_ms.

## 10. Performance Considerations
Indexes: matches(kickoff_at), predictions(match_id,user_id), leaderboard(generated_at,rank). Incremental recalculation user subset only.

## 11. Security Notes
Password hashing Argon2; rate limit login attempts; no full user enumeration; playoff lock prevents post-kickoff manipulations.

## 12. Testing Strategy
ExUnit per context; property tests optional for scoring; LiveView render + event tests for UI flows.

## 13. Completion Definition
All acceptance criteria pass; coverage ≥60%; deployment test gate; locks enforced; scoring verified sample dataset.

## 14. Future Enhancements (Deferred)
- Email verification
- Multi-region Fly.io
- Real-time broadcasting of leaderboard changes
- Knockout match exact scores
- Metrics/Tracing integration.

## 15. Risks & Mitigation
Leaderboard latency: incremental updates.
Lock race: DB predicate on update.
Scoring correctness: pure functions + tests.

## 16. Rollback Plan
If scoring failure: run full rescore Mix task; restore previous leaderboard snapshot backup.

## 17. CLI Tasks Planned
- predictions.rescore
- leaderboard.snapshot
- (optional) data.seed

## 18. Open Issues
None.

Status: PLAN COMPLETE.
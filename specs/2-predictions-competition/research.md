# Research & Decisions: World Cup 2026 Prediction Competition

## 1. Password Hashing
Decision: Argon2 (argon2_elixir)
Rationale: Modern, memory-hard.

## 2. Leaderboard Strategy
Decision: Incremental update (affected users only).
Rationale: Performance & latency.

## 3. Fly.io Scaling
Decision: Single app, 1–2 instances.
Rationale: Simplicity MVP.

## 4. Lock Enforcement
Decision: DB predicate (WHERE kickoff_at > now()) + UI disable.
Rationale: Prevent race edits.

## 5. Scoring Implementation
Decision: Pure functions in Scoring context.
Rationale: Testability & determinism.

## 6. Playoff Picks Storage
Decision: One row per stage with array of team_ids.
Rationale: Compact; simple correctness check.

## 7. Rate Limiting Auth
Decision: ETS counter per IP/email.
Rationale: Lightweight.

## 8. Deployment Test Gate
Decision: Run mix test in image before deploy.
Rationale: Artifact integrity.

## 9. Observability Minimum
Decision: Structured Logger events + request metadata.
Rationale: Low overhead baseline.

## 10. Accessibility
Decision: Semantic HTML + contrast compliance.
Rationale: Quick win WCAG baseline.

All prior clarifications resolved; no outstanding research blockers.
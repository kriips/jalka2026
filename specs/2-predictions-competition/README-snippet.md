# World Cup 2026 Prediction Competition (Spec Assets)

This directory contains specification and planning artifacts:
- spec.md – Formal feature specification
- impl-plan.md – Implementation planning and technical context
- research.md – Decision log
- data-model.md – Data entities and constraints
- contracts/openapi.yaml – HTTP API contract draft
- tasks.md – Execution task list (111 tasks)

MVP: Authentication, group predictions, landing page.

Lock Rules: Per-match group predictions at kickoff; all playoff picks locked at tournament kickoff.

Scoring: Group outcome=1, exact score bonus=1; R16=1, QF=3, SF=5, Finalist=6, Champion=8.

Next Step: Begin Phase 1 tasks (T001–T015).
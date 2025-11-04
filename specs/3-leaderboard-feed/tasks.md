# Implementation Tasks: Leaderboard Auto-Recalculation & External Results Feed

## Phase 1: Setup
- [ ] T001 Ensure feature branch `003-leaderboard-feed` is checked out
- [ ] T002 Add environment variable placeholders to .env.example (FEED_ENABLED, FEED_API_KEY, FEED_URL, POLLING_INTERVAL_SECONDS, MAX_RETRIES)
- [ ] T003 Create migration stubs directory planning note docs/migrations/leaderboard_feed_plan.md
- [ ] T004 [P] Add initial config keys in config/runtime.exs (feed_enabled, polling_interval_seconds fallback)
- [ ] T005 Add application supervision hook placeholder in lib/jalka2026/application.ex (commented ingestion supervisor)
- [ ] T006 [P] Add documentation header for feed in README.md (section: Leaderboard Feed)
- [ ] T007 Define feature toggle pattern doc docs/feature_toggles.md
- [ ] T008 Add Credo rule note for new contexts in .credo.exs (if not present)
- [ ] T009 [P] Prepare test support module for time freeze test/support/time_helpers.ex
- [ ] T010 Add mix alias for full rescore (comment placeholder) in mix.exs

## Phase 2: Foundational
- [ ] T011 Create migration: create_ingestion_events priv/repo/migrations/*_create_ingestion_events.exs
- [ ] T012 Create migration: create_conflict_records priv/repo/migrations/*_create_conflict_records.exs
- [ ] T013 Create migration: create_scoring_events priv/repo/migrations/*_create_scoring_events.exs
- [ ] T014 Create migration: add_columns_configuration priv/repo/migrations/*_add_configuration_table.exs
- [ ] T015 [P] Add schema IngestionEvent lib/jalka2026/ingestion/ingestion_event.ex
- [ ] T016 Add schema ConflictRecord lib/jalka2026/ingestion/conflict_record.ex
- [ ] T017 [P] Add schema ScoringEvent lib/jalka2026/scoring/scoring_event.ex
- [ ] T018 Add schema Configuration lib/jalka2026/ingestion/configuration.ex (singleton row behavior)
- [ ] T019 Implement ingestion repo access functions lib/jalka2026/ingestion.ex
- [ ] T020 [P] Implement scoring event repository functions lib/jalka2026/scoring/events.ex
- [ ] T021 Write migrations tests (if using sandbox) test/ingestion/migrations_validate_test.exs
- [ ] T022 Create factory entries for new schemas test/support/factory.ex
- [ ] T023 [P] Add changeset validations (polling interval >=30, retries bounds) in configuration.ex
- [ ] T024 Add seed placeholder for configuration entry priv/repo/seeds.exs
- [ ] T025 Implement payload validation module lib/jalka2026/ingestion/payload_validator.ex

## Phase 3: [US1] Auto Scoring After Manual Result Entry
Story Goal: When admin records match final score, system triggers incremental scoring and updates leaderboard.
Independent Test Criteria: ScoringEvent created; affected users count >0 when predictions exist; leaderboard snapshot updated; latency recorded.
- [ ] T026 [US1] Add hook in match result update (lib/jalka2026/matches.ex) to call scoring orchestrator
- [ ] T027 [P] [US1] Expose scoring orchestrator entrypoint lib/jalka2026/scoring/orchestrator.ex
- [ ] T028 [US1] Leaderboard incremental update integration lib/jalka2026/leaderboard/incremental.ex (reuse existing) ensure callable
- [ ] T029 [US1] Record ScoringEvent after update lib/jalka2026/scoring/orchestrator.ex
- [ ] T030 [P] [US1] Write unit tests for orchestrator trigger test/scoring/orchestrator_trigger_test.exs
- [ ] T031 [US1] Write integration test manual result scoring test/scoring/manual_result_scoring_test.exs
- [ ] T032 [US1] Add latency capture (start/end timing) lib/jalka2026/scoring/orchestrator.ex
- [ ] T033 [US1] Update README scoring section README.md

## Phase 4: [US2] Feed Ingestion Polling
Story Goal: Poll external feed at interval; ingest new completed match results.
Independent Test Criteria: Poll executes on interval; new result -> ingestion event success; duplicate -> no-op; failures -> retries/backoff.
- [ ] T034 [US2] Implement ingestion supervisor lib/jalka2026/ingestion/supervisor.ex
- [ ] T035 [P] [US2] Implement polling worker lib/jalka2026/ingestion/polling_worker.ex
- [ ] T036 [US2] Add HTTP client wrapper lib/jalka2026/ingestion/http_client.ex (Finch based)
- [ ] T037 [US2] Configure Finch pool in application supervision lib/jalka2026/application.ex
- [ ] T038 [P] [US2] Implement retry/backoff helper lib/jalka2026/ingestion/backoff.ex
- [ ] T039 [US2] Integrate configuration lookup + disabled check polling_worker.ex
- [ ] T040 [P] [US2] Implement result parsing & validation lib/jalka2026/ingestion/parse_and_validate.ex
- [ ] T041 [US2] Create ingestion event log function ingestion.ex (success/error/no-op)
- [ ] T042 [US2] Trigger scoring on new valid completed result ingestion.ex
- [ ] T043 [US2] Tests: polling interval & disable behavior test/ingestion/polling_interval_test.exs
- [ ] T044 [P] [US2] Tests: retry/backoff sequences test/ingestion/backoff_test.exs
- [ ] T045 [US2] Tests: duplicate ingestion no-op test/ingestion/noop_ingestion_test.exs
- [ ] T046 [US2] Tests: successful ingestion scoring chain test/ingestion/ingestion_scoring_chain_test.exs
- [ ] T047 [US2] Tests: failure threshold triggers degraded mode test/ingestion/degraded_mode_test.exs
- [ ] T048 [US2] Update quickstart feed enable steps quickstart.md

## Phase 5: [US3] Conflict Detection & Resolution
Story Goal: Detect differing scores, create conflict record, admin resolves approve/reject.
Independent Test Criteria: ConflictRecord created on differing scores; approve overwrites + scoring; reject preserves; audit entries logged.
- [ ] T049 [US3] Implement conflict detection comparison lib/jalka2026/ingestion/conflict_detector.ex
- [ ] T050 [P] [US3] Integrate detector in ingestion flow ingestion.ex
- [ ] T051 [US3] Implement conflict resolution service lib/jalka2026/ingestion/conflict_resolution.ex
- [ ] T052 [US3] Add admin LiveView for conflicts lib/jalka2026_web/live/admin_conflicts_live.ex
- [ ] T053 [US3] Add approve endpoint (if HTTP) lib/jalka2026_web/controllers/conflict_approve_controller.ex
- [ ] T054 [P] [US3] Add reject endpoint lib/jalka2026_web/controllers/conflict_reject_controller.ex
- [ ] T055 [US3] Tests: conflict creation test/ingestion/conflict_creation_test.exs
- [ ] T056 [P] [US3] Tests: approve flow scoring test/ingestion/conflict_approve_test.exs
- [ ] T057 [US3] Tests: reject flow test/ingestion/conflict_reject_test.exs
- [ ] T058 [US3] Tests: resolution audit entries test/ingestion/conflict_audit_test.exs
- [ ] T059 [US3] Update README conflict section README.md

## Phase 6: [US4] Rescore Operations (Incremental & Full)
Story Goal: Support targeted rescore and full rescore per boundary rules.
Independent Test Criteria: Full rescore recalculates all scoring events; targeted only one match; boundary condition triggers full on playoff corrections.
- [ ] T060 [US4] Implement full rescore Mix task lib/mix/tasks/leaderboard.full_rescore.ex
- [ ] T061 [P] [US4] Implement incremental rescore API endpoint lib/jalka2026_web/controllers/rescore_incremental_controller.ex
- [ ] T062 [US4] Implement full rescore service lib/jalka2026/scoring/full_rescore.ex
- [ ] T063 [US4] Ensure orchestrator path mode flag (incremental|full) scoring/orchestrator.ex
- [ ] T064 [P] [US4] Tests: full rescore correctness test/scoring/full_rescore_test.exs
- [ ] T065 [US4] Tests: incremental rescore test/scoring/incremental_rescore_test.exs
- [ ] T066 [US4] Tests: boundary playoff correction triggers full test/scoring/playoff_boundary_rescore_test.exs
- [ ] T067 [US4] Logging validation test/scoring/rescore_logging_test.exs
- [ ] T068 [US4] Update quickstart rescore section quickstart.md

## Phase 7: [US5] Admin Feed Status Dashboard
Story Goal: Admin observes ingestion status (last fetch, conflicts count, degraded mode state).
Independent Test Criteria: Dashboard shows accurate counts; updates after events; hides feed controls when disabled.
- [ ] T069 [US5] Implement status aggregation function ingestion/status_aggregator.ex
- [ ] T070 [P] [US5] Admin LiveView status page lib/jalka2026_web/live/admin_feed_status_live.ex
- [ ] T071 [US5] Controller endpoint /admin/feed/status if needed lib/jalka2026_web/controllers/feed_status_controller.ex
- [ ] T072 [US5] Tests: status aggregation test/ingestion/status_aggregator_test.exs
- [ ] T073 [P] [US5] Tests: LiveView status render test/web/admin_feed_status_live_test.exs
- [ ] T074 [US5] Tests: status updates after ingestion event test/ingestion/status_update_after_ingest_test.exs
- [ ] T075 [US5] README update feed status section README.md

## Phase 8: [US6] Observability & Logging Enhancements
Story Goal: Structured logs and latency metrics recorded for ingestion & scoring.
Independent Test Criteria: Log entries contain required fields; latency_ms stored; no duplicate log spam.
- [ ] T076 [US6] Implement structured logging helper lib/jalka2026/ingestion/log.ex
- [ ] T077 [P] [US6] Add logging calls to polling_worker.ex
- [ ] T078 [US6] Add logging calls to scoring orchestrator orchestrator.ex
- [ ] T079 [US6] Tests: ingestion log format test/ingestion/log_format_test.exs
- [ ] T080 [P] [US6] Tests: scoring latency recorded test/scoring/latency_record_test.exs
- [ ] T081 [US6] Tests: duplicate no-op log suppression test/ingestion/noop_log_suppression_test.exs
- [ ] T082 [US6] Add documentation of log schema docs/logging_schema.md

## Phase 9: Polish & Cross-Cutting
- [ ] T083 Audit configuration validation edge cases test/ingestion/config_validation_test.exs
- [ ] T084 Add degraded mode banner component lib/jalka2026_web/components/degraded_banner_component.ex
- [ ] T085 [P] Add CSV export ingestion events lib/jalka2026/ingestion/export_events.ex
- [ ] T086 Performance smoke script scripts/perf_ingestion_smoke.sh
- [ ] T087 [P] Add security review notes docs/security_review_feed.md
- [ ] T088 Add refactor notes docs/refactor_feed_notes.md
- [ ] T089 Coverage threshold check update .github/workflows/ci.yml
- [ ] T090 Final README polish README.md

## Dependencies (Story Order)
US1 → US2 → US3 → US4 → US5 → US6 (observability can partially start earlier but final integration after scoring).

## Parallel Execution Examples
- Phase 2: T015 & T016 & T017 in parallel (distinct schemas)
- US2: T035, T038, T040 parallel (worker/backoff/parser)
- US3: T050 & T056 concurrently (detector + approve tests)
- US4: T061 & T064 parallel (incremental endpoint + full rescore tests)
- US6: T077 & T080 parallel (logging ingestion + latency tests)

## Implementation Strategy
MVP: Phases 1–3 (auto scoring manual results). Next increments add feed ingestion (US2), then conflicts (US3), then rescore operations (US4), dashboard (US5), observability (US6), polish.

## Independent Test Criteria Summary
- US1: Incremental scoring triggers, event recorded, latency captured.
- US2: Polling interval respected, retry/backoff works, duplicate no-op.
- US3: Conflict detection & approve/reject flows update scores correctly.
- US4: Full rescore recalculates all; incremental limited scope; playoff correction triggers full.
- US5: Status dashboard reflects ingestion events & conflict counts.
- US6: Structured logs present; latency metrics recorded; no duplicate no-op spam.

## Task Counts
- Setup: 10
- Foundational: 15
- US1: 8
- US2: 15
- US3: 11
- US4: 9
- US5: 7
- US6: 7
- Polish: 8
Total: 90

## Format Validation
All tasks follow: - [ ] T### optional [P] optional [US#] Description with file path.

Status: TASKS DRAFT
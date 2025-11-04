# Implementation Tasks: World Cup 2026 Prediction Competition

## Phase 1: Setup
- [ ] T001 Initialize Phoenix project structure (mix phx.new jalka2026)
- [ ] T002 Add Argon2 dependency to mix.exs (argon2_elixir)
- [ ] T003 Add Credo & ExCoveralls to mix.exs for lint & coverage
- [ ] T004 Configure Tailwind (assets/tailwind.config.js) palette (blue/black/white)
- [ ] T005 [P] Create Dockerfile for Fly.io deployment (./Dockerfile)
- [ ] T006 Add fly.toml template (./fly.toml)
- [ ] T007 Set up .tool-versions for Elixir/Erlang versions (.tool-versions)
- [ ] T008 Add environment variable loading (config/runtime.exs)
- [ ] T009 Configure Logger metadata (config/config.exs)
- [ ] T010 Add basic health & readiness endpoints (lib/jalka2026_web/router.ex)
- [ ] T011 Set up GitHub Actions CI (./.github/workflows/ci.yml)
- [ ] T012 Create README with quickstart (README.md)
- [ ] T013 Add CODEOWNERS file (./CODEOWNERS)
- [ ] T014 Configure formatter & credo settings (.credo.exs)
- [ ] T015 Add .env.example with required vars (.env.example)

## Phase 2: Foundational
- [ ] T016 Create base Repo & telemetry config (lib/jalka2026/application.ex)
- [ ] T017 Migration: users table (priv/repo/migrations/001_create_users.exs)
- [ ] T018 Migration: teams table (priv/repo/migrations/002_create_teams.exs)
- [ ] T019 Migration: group_matches table (priv/repo/migrations/003_create_group_matches.exs)
- [ ] T020 Migration: score_predictions table (priv/repo/migrations/004_create_score_predictions.exs)
- [ ] T021 Migration: playoff_stage_predictions table (priv/repo/migrations/005_create_playoff_stage_predictions.exs)
- [ ] T022 Migration: advancements table (priv/repo/migrations/006_create_advancements.exs)
- [ ] T023 Migration: scoring_results table (priv/repo/migrations/007_create_scoring_results.exs)
- [ ] T024 Migration: playoff_scoring_results table (priv/repo/migrations/008_create_playoff_scoring_results.exs)
- [ ] T025 Migration: leaderboard_snapshots table (priv/repo/migrations/009_create_leaderboard_snapshots.exs)
- [ ] T026 Seed teams/groups (priv/repo/seeds.exs)
- [ ] T027 [P] Implement User schema & changeset (lib/jalka2026/accounts/user.ex)
- [ ] T028 Implement Accounts context (lib/jalka2026/accounts.ex)
- [ ] T029 Implement Team schema & context (lib/jalka2026/teams/team.ex, lib/jalka2026/teams.ex)
- [ ] T030 Base Match schema & context (lib/jalka2026/matches/match.ex, lib/jalka2026/matches.ex)
- [ ] T031 Add test factories (test/support/factory.ex)
- [ ] T032 Base test helper coverage config (test/test_helper.exs)

## Phase 3: US1 Registration & Authentication
- [ ] T033 Add registration controller (lib/jalka2026_web/controllers/registration_controller.ex)
- [ ] T034 Add login controller (lib/jalka2026_web/controllers/session_controller.ex)
- [ ] T035 Session plug & fetch user (lib/jalka2026_web/plugs/session.ex)
- [ ] T036 Rate limit plug for auth (lib/jalka2026_web/plugs/rate_limit_auth.ex)
- [ ] T037 Registration LiveView (lib/jalka2026_web/live/registration_live.ex)
- [ ] T038 Login LiveView (lib/jalka2026_web/live/login_live.ex)
- [ ] T039 Enforce kickoff cutoff (lib/jalka2026/accounts.ex)
- [ ] T040 Password hashing integration (lib/jalka2026/accounts/user.ex)
- [ ] T041 Auth tests (test/accounts/auth_flow_test.exs)
- [ ] T042 Rate limit tests (test/web/rate_limit_auth_test.exs)
- [ ] T043 Registration cutoff tests (test/accounts/registration_cutoff_test.exs)
- [ ] T044 Router updates (lib/jalka2026_web/router.ex)

## Phase 4: US2 Group Predictions
- [ ] T045 ScorePrediction schema (lib/jalka2026/predictions/score_prediction.ex)
- [ ] T046 Predictions context functions (lib/jalka2026/predictions.ex)
- [ ] T047 Lock enforcement guard (lib/jalka2026/predictions.ex)
- [ ] T048 Group predictions LiveView (lib/jalka2026_web/live/group_predictions_live.ex)
- [ ] T049 Missing predictions indicator (lib/jalka2026/predictions.ex)
- [ ] T050 Prediction creation tests (test/predictions/create_prediction_test.exs)
- [ ] T051 Lock enforcement tests (test/predictions/lock_test.exs)
- [ ] T052 Validation tests (test/predictions/validation_test.exs)
- [ ] T053 Router updates (lib/jalka2026_web/router.ex)
- [ ] T054 Match listing component (lib/jalka2026_web/components/match_list_component.ex)
- [ ] T055 Reschedule lock update logic (lib/jalka2026/matches.ex)
- [ ] T056 Reschedule tests (test/matches/reschedule_lock_test.exs)
- [ ] T057 Factory additions (test/support/factory.ex)
- [ ] T058 Missing prediction count tests (test/predictions/missing_count_test.exs)

## Phase 5: US3 Playoff Stage Picks
- [ ] T059 PlayoffStagePrediction schema (lib/jalka2026/playoffs/playoff_stage_prediction.ex)
- [ ] T060 Playoffs context (lib/jalka2026/playoffs.ex)
- [ ] T061 Global lock check (lib/jalka2026/playoffs.ex)
- [ ] T062 Duplicate team validation (lib/jalka2026/playoffs.ex)
- [ ] T063 Playoff picks LiveView (lib/jalka2026_web/live/playoff_picks_live.ex)
- [ ] T064 Champion consistency rule (lib/jalka2026/playoffs.ex)
- [ ] T065 Stage length tests (test/playoffs/stage_length_test.exs)
- [ ] T066 Global lock tests (test/playoffs/global_lock_test.exs)
- [ ] T067 Duplicate prevention tests (test/playoffs/duplicates_test.exs)
- [ ] T068 Router additions (lib/jalka2026_web/router.ex)
- [ ] T069 Factory updates (test/support/factory.ex)

## Phase 6: US4 Scoring & Leaderboard
- [ ] T070 Group scoring functions (lib/jalka2026/scoring/group.ex)
- [ ] T071 Playoff scoring functions (lib/jalka2026/scoring/playoff.ex)
- [ ] T072 Scoring orchestrator (lib/jalka2026/scoring.ex)
- [ ] T073 Leaderboard context (lib/jalka2026/leaderboard.ex)
- [ ] T074 Incremental leaderboard logic (lib/jalka2026/leaderboard/incremental.ex)
- [ ] T075 Mix task: full rescore (lib/mix/tasks/predictions.rescore.ex)
- [ ] T076 Leaderboard LiveView (lib/jalka2026_web/live/leaderboard_live.ex)
- [ ] T077 Group scoring tests (test/scoring/group_scoring_test.exs)
- [ ] T078 Playoff scoring tests (test/scoring/playoff_scoring_test.exs)
- [ ] T079 Incremental leaderboard tests (test/leaderboard/incremental_test.exs)
- [ ] T080 Rescore Mix task tests (test/mix/rescore_task_test.exs)
- [ ] T081 Tie-break tests (test/leaderboard/tiebreak_test.exs)

## Phase 7: US5 Admin Management
- [ ] T082 Admin guard plug (lib/jalka2026_web/plugs/admin_guard.ex)
- [ ] T083 Admin match results LiveView (lib/jalka2026_web/live/admin_match_results_live.ex)
- [ ] T084 Admin advancement LiveView (lib/jalka2026_web/live/admin_advancements_live.ex)
- [ ] T085 Advancement schema & methods (lib/jalka2026/playoffs/advancement.ex, lib/jalka2026/playoffs.ex)
- [ ] T086 Result entry triggers scoring (lib/jalka2026/matches.ex)
- [ ] T087 Advancement triggers playoff scoring (lib/jalka2026/playoffs.ex)
- [ ] T088 Audit log event emission (lib/jalka2026/scoring.ex)
- [ ] T089 Result scoring tests (test/admin/result_scoring_test.exs)
- [ ] T090 Advancement scoring tests (test/admin/advancement_scoring_test.exs)
- [ ] T091 Admin guard tests (test/web/admin_guard_test.exs)
- [ ] T092 Admin router scope (lib/jalka2026_web/router.ex)
- [ ] T093 Factory: advancements (test/support/factory.ex)

## Phase 8: US6 Landing Page & Public Rules
- [ ] T094 Landing page LiveView (lib/jalka2026_web/live/landing_live.ex)
- [ ] T095 Scoring examples component (lib/jalka2026_web/components/scoring_examples_component.ex)
- [ ] T096 Countdown component (lib/jalka2026_web/components/countdown_component.ex)
- [ ] T097 Style utility classes (assets/css/app.css)
- [ ] T098 Accessibility tests (test/web/accessibility_landing_test.exs)
- [ ] T099 Landing content tests (test/web/landing_content_test.exs)
- [ ] T100 Router public route (lib/jalka2026_web/router.ex)
- [ ] T101 README examples (README.md)

## Phase 9: Polish & Cross-Cutting
- [ ] T102 Structured scoring logging (lib/jalka2026/scoring.ex)
- [ ] T103 Log metadata plug (lib/jalka2026_web/plugs/log_metadata.ex)
- [ ] T104 CSV export (lib/jalka2026/leaderboard/export.ex)
- [ ] T105 CSV export tests (test/leaderboard/export_test.exs)
- [ ] T106 Rate limit storage reset (lib/jalka2026_web/plugs/rate_limit_auth.ex)
- [ ] T107 Security review checklist (docs/security_review.md)
- [ ] T108 Performance smoke script (scripts/perf_smoke.sh)
- [ ] T109 Mix task: leaderboard snapshot (lib/mix/tasks/leaderboard.snapshot.ex)
- [ ] T110 Coverage threshold in CI (./.github/workflows/ci.yml)
- [ ] T111 Final refactor notes (docs/refactor_pass.md)

## Parallel Opportunities
US1: T033 & T034 parallel. US2: T045–T046 parallel. US4: T070 & T071 parallel. US5: T082 & T085 parallel. US6: T094 & T095 parallel.

## MVP Scope
US1 + US2 + basic landing (T033–T058, T094, T099, T100).

## Completion Criteria
All acceptance criteria met; coverage ≥60%; locks enforced; scoring correct; deployment pipeline passes test gate.

Total tasks: 111
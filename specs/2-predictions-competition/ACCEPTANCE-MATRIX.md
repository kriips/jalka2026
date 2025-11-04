# Acceptance Criteria Matrix

| ID | Requirement Ref | Test Path | Auto? | Notes |
|----|------------------|-----------|-------|-------|
| AC1 | FR7/Lock | test/predictions/lock_test.exs | Yes | Edit after kickoff denied |
| AC2 | FR8/Scoring | test/scoring/group_scoring_test.exs | Yes | Outcome vs exact points |
| AC3 | FR11/Playoff scoring | test/scoring/playoff_scoring_test.exs | Yes | Stage points mapping |
| AC4 | FR12/Playoff lock | test/playoffs/global_lock_test.exs | Yes | Lock at tournament start |
| AC5 | FR15/Leaderboard | test/leaderboard/tiebreak_test.exs | Yes | Tie-break ordering |
| AC6 | FR21/Audit timestamps | test/predictions/create_prediction_test.exs | Yes | Timestamp presence |
| AC7 | FR24/Missing prediction zero | test/predictions/missing_count_test.exs | Yes | Zero points assigned |
| AC8 | FR27/Landing examples | test/web/landing_content_test.exs | Yes | Examples rendered |
| AC9 | FR75/Rescore Mix task | test/mix/rescore_task_test.exs | Yes | Idempotent rescore |
| AC10 | FR36/CLI scope | test/mix/rescore_task_test.exs | Partial | Ensure only intended tasks exist |

Total: 10 criteria tracked.
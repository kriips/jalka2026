# Feature Specification: World Cup 2026 Prediction Competition (Signup, Group Scores, Playoff Stage Picks, Landing Page)

## 1. Feature Summary
Provide public signup before the 2026 tournament, enable users to predict every group stage match by exact score (1 point correct outcome +1 additional for exact score), and select which teams reach each knockout stage. Playoff scoring: each correct Round of 16 team =1 point, Quarterfinalist =3, Semifinalist =5, Finalist =6, Champion =8. Include a static landing page explaining rules with a sleek modern style (blue, black, white).

## 2. Problem Statement
Participants need a fair, engaging platform to submit structured predictions (group match scores and knockout stage advancement) before matches start, earning points that drive leaderboard competition.

## 3. Goals
- User registration before tournament start.
- Exact score predictions for all group matches.
- Stage advancement predictions for playoff rounds (R16, QF, SF, Final, Champion).
- Transparent scoring (group + playoff).
- Static landing page describing rules.
- Accurate leaderboard with tie-break metrics.
- Locking prevents post-kickoff edits.

## 4. Non-Goals
- Live in‑match updates.
- Cash or prize handling.
- Social features.
- Multi-language localization.
- Mobile app (responsive web only).
- Predicting exact playoff match scores (advancement only).

## 5. Actors
- Participant: registers, submits predictions, views leaderboard, dashboard.
- Admin: manages schedule, enters results, confirms advancing teams, triggers recalculation.
- Visitor: reads landing page, may register (until cutoff).

## 6. User Scenarios
1. Visitor reads rules and registers pre-cutoff.
2. Participant completes group score predictions progressively.
3. Participant selects advancing teams for playoff stages before their lock.
4. Participant attempts to edit a locked match prediction → denied.
5. Admin enters final group match score → system scores predictions and updates leaderboard.
6. Admin marks playoff advancing teams → playoff predictions scored.
7. Participant views playoff scoring breakdown and cumulative points.
8. Participant sees champion prediction correctness after final.

## 7. Functional Requirements
FR1 Registration captures email, display name, password (unique email).  
FR2 Login/logout/session available.  
FR3 Landing page presents: competition overview, scoring examples (group + playoff), deadlines, tie-breaks.  
FR4 List all group matches with teams, kickoff time, inputs for predicted home/away score.  
FR5 Validate score inputs: integers 0–20.  
FR6 Allow saving partial predictions.  
FR7 Lock each group match prediction at its kickoff time.  
FR8 Group scoring: correct outcome (win/draw) =1 point; exact score adds +1 (total 2 max per match).  
FR9 Provide playoff prediction interface: select teams for each stage (R16, QF, SF, Final, Champion).  
FR10 Prevent duplicate team selections within the same stage.  
FR11 Playoff scoring model (advancement correctness): R16 team =1, QF team =3, SF team =5, Finalist =6, Champion =8 (cumulative across stages if separately predicted).  
FR12 Playoff predictions lock: all playoff stage picks (R16, QF, SF, Final, Champion) must be submitted before first tournament match kickoff; after kickoff no additions or edits.  
FR13 Registration cutoff: registration closes exactly at first tournament match kickoff (no new accounts afterward).  
FR14 After lock, disallow edits (group or playoff).  
FR15 Leaderboard fields: rank, display name, total points, exact score count, correct outcome count, playoff points, tie-break metrics.  
FR16 Tie-break order: total points > exact scores count > correct outcomes count > earliest registration timestamp (stable deterministic).  
FR17 Participant dashboard shows status tags: Pending, Locked, Scored, Correct/Incorrect.  
FR18 Indicator of missing group predictions (count + list).  
FR19 Admin can create/update matches, enter final scores, set advancing teams per stage.  
FR20 Automatic recalculation on score or advancement changes.  
FR21 Audit timestamps for every prediction create/update.  
FR22 Privacy: no viewing other users’ detailed pre-kickoff score predictions; aggregate stats only.  
FR23 Rescheduled match adjusts lock if still future.  
FR24 Missing prediction at lock yields zero points.  
FR25 Accessibility: clear labels, keyboard navigation, color contrast within blue/black/white palette.  
FR26 Styling guideline: sleek, modern, restrained palette (blue primary, black text accents, white backgrounds).  
FR27 Landing page must include at least two concrete scoring examples (e.g., 2–1 exact vs 2–1 predicted).  
FR28 Leaderboard updates within 1 minute of scoring event (admin result or advancement update).  
FR29 Champion prediction evaluated only after final match completion.  
FR30 Prevent selecting eliminated teams for later stages once official elimination recorded.  
FR31 Provide playoff scoring breakdown per user (stage-by-stage points).  
FR32 Export (CSV) admin aggregate scoreboard (group + playoff totals).  
FR33 Show countdown to next match kickoff and next playoff lock deadline.  
FR34 Handle playoff bracket anomalies via admin override (marks overridden; still scores).  
FR35 System logs scoring batch executions for traceability.  
FR36 CLI/Mix tasks limited to batch/maintenance & scoring operations (e.g., full rescore, data import seed); all other interactions via LiveView/API only.  

## 8. Success Criteria
SC1 90% of registered users submit ≥80% of group match predictions before their kickoffs.  
SC2 Leaderboard reflects new scoring within ≤1 minute for 95% of scoring events.  
SC3 Median time from registration to first 10 match predictions ≤7 minutes.  
SC4 <3% of prediction submissions fail validation first attempt.  
SC5 100% of locked predictions reject edits.  
SC6 ≥85% user survey clarity rating on scoring rules.  
SC7 ≥70% users submit playoff stage predictions before the playoff lock(s).  
SC8 Zero duplicate team selections per stage in stored playoff predictions.  
SC9 All champion predictions scored correctly within 5 minutes of final result entry.  

## 9. Key Entities
User: id, email, display_name, registered_at.  
Team: id, name, group.  
GroupMatch: id, group, home_team_id, away_team_id, kickoff_at, status, final_home_score, final_away_score.  
ScorePrediction: id, user_id, match_id, predicted_home, predicted_away, created_at, updated_at, locked_at.  
PlayoffStagePrediction: id, user_id, stage (r16|qf|sf|final|champion), team_ids[], submitted_at, locked_at.  
ScoringResult (group): prediction_id, outcome_points, exact_points, total_points.  
PlayoffScoringResult: user_id, stage, correct_team_ids[], stage_points.  
LeaderboardEntry (derived): user_id, total_points, exact_scores_count, correct_outcomes_count, playoff_points, tie_break_metrics.  

## 10. Edge Cases
- Rescheduled kickoff shifts lock (if future).  
- Incorrect admin result corrected → full recalculation.  
- User omits playoff selections → zero for those stages.  
- Match canceled → mark predictions canceled, award no points.  
- Simultaneous multiple result/advancement updates maintain deterministic scoreboard order.  
- Overlapping scoring: champion contributes to champion stage only; earlier stage lists scored independently (cumulative).  
- Team name change mid-tournament (display updated, ID constant).  

## 11. Assumptions
A1 Per-match lock for group predictions.  
A2 Playoff scoring cumulative across stages (if user predicted presence in each list).  
A3 Manual admin input for results and advancing teams.  
A4 Single timezone baseline (UTC) with local display.  
A5 Tie-break sequence sufficient for uniqueness (expect low collision probability).  
A6 No third-place match scoring in initial release.  
A7 Champion prediction separate from finalist list (finalist points + champion points if both correct).  
A8 Registration unavailable after first match kickoff (cutoff enforced).  
A9 All playoff stage picks locked at tournament kickoff (single global lock).  
A10 Operational CLI limited to maintenance & scoring only (no broad per-context CLI surface).  

## 12. Dependencies
- Reliable schedule data.  
- Authentication + session system.  
- Time source (server) for lock enforcement.  
- Admin tooling for advancement confirmation.  

## 13. Risks
- Unclear playoff locking could confuse timing for submissions.  
- Late advancement updates may delay scoring transparency.  
- Cumulative playoff scoring may over-weight later stages if misunderstood.  
- Over-exposed CLI could increase maintenance overhead (mitigated by FR36).  

## 14. Out of Scope
- Real-time match commentary.  
- Exact score predictions for playoff matches.  
- Prize management, payments.  
- Social or chat features.  

## 15. Open Questions
(None – current clarifications integrated.)

## 16. Clarification Markers
(None remaining.)

## 17. Acceptance Criteria (Samples)
AC1 Editing group prediction after kickoff returns denial message; data unchanged.  
AC2 Exact outcome but wrong score yields 1 point; exact match yields 2 points.  
AC3 Correct semifinal team yields 5 playoff points; correct finalist yields 6 (not additive to 5 unless also predicted in semifinal list—cumulative model honored).  
AC4 Champion correct yields 8 points (plus earlier stage points if predicted).  
AC5 Leaderboard shows updated totals ≤1 minute after scoring recalculation.  
AC6 Duplicate team selection attempt in a stage blocked with validation message.  
AC7 Missing prediction at lock scored zero.  
AC8 Landing page displays at least two illustrated scoring examples (group + playoff).  
AC9 Running Mix task for full rescore updates leaderboard consistently and logs completion entry.  

## 18. Monitoring & Evaluation
Track: prediction completion %, playoff submission rate, leaderboard update latency, error rate on submissions, user clarity survey results.  

## 19. Glossary
Outcome: Win/Draw classification of a match.  
Exact Score: Predicted scores equal final scores.  
Lock: Prediction becomes immutable.  
Stage Pick: Selecting team(s) expected to reach a playoff round.  

## 20. Privacy
Minimal personal data (email, display name). Users may request deletion (future enhancement).  

## Clarifications
### Session 2025-11-04
- Q: Registration cutoff timing → A: Close at first tournament match kickoff
- Q: Playoff prediction locking timing → A: All playoff picks lock at tournament kickoff
- Q: CLI/Mix task exposure rule → A: Only batch/maintenance and scoring operations require Mix tasks; others LiveView/API only.

Status: SPEC UPDATED  
Readiness: Ready for implementation planning.

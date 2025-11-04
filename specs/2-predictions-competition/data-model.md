# Data Model

## Entities

### User
Fields: id (UUID), email (unique, lowercase), display_name (string), password_hash (string), admin (boolean, default false), inserted_at, updated_at.
Constraints: unique(email).
Validation: display_name length 2–40; email format.

### Team
Fields: id (UUID), name (string), group_code (string A–H), inserted_at, updated_at.
Constraints: unique(name + group_code).

### GroupMatch
Fields: id (UUID), group_code, home_team_id (FK Team), away_team_id (FK Team), kickoff_at (UTC datetime), status (enum scheduled|completed|canceled), final_home_score (int nullable), final_away_score (int nullable), inserted_at, updated_at.
Constraints: unique(home_team_id + away_team_id + kickoff_at).
State transitions: scheduled → completed|canceled.

### ScorePrediction
Fields: id (UUID), user_id (FK User), match_id (FK GroupMatch), predicted_home (int 0–20), predicted_away (int 0–20), locked_at (datetime nullable), inserted_at, updated_at.
Constraints: unique(user_id + match_id).
Lock rule: no updates if now() >= match.kickoff_at.

### PlayoffStagePrediction
Fields: id (UUID), user_id (FK User), stage (enum r16|qf|sf|final|champion), team_ids (array[UUID]), locked_at (datetime nullable), inserted_at, updated_at.
Constraints: unique(user_id + stage).
Validation: team_ids length: r16=16, qf=8, sf=4, final=2, champion=1; no duplicates.

### Advancement
Fields: id (UUID), stage (enum r16|qf|sf|final|champion), team_id (FK Team), inserted_at.
Used to score playoff predictions.

### ScoringResult (Group)
Fields: id (UUID), prediction_id (FK ScorePrediction), outcome_points (0|1), exact_points (0|1), total_points (0–2), inserted_at.

### PlayoffScoringResult
Fields: id (UUID), user_id (FK User), stage (enum), correct_team_ids (array[UUID]), stage_points (int), inserted_at.

### LeaderboardSnapshot
Fields: id (UUID), generated_at (datetime), user_id (FK User), total_points (int), exact_scores_count (int), correct_outcomes_count (int), playoff_points (int), rank (int).

## Relationships
User 1..* ScorePrediction
User 1..* PlayoffStagePrediction
GroupMatch 1..* ScorePrediction
User 1..* PlayoffScoringResult
Team participates many GroupMatches
Advancement drives PlayoffScoringResult

## Validation Rules Summary
Scores: 0–20 integers.
Playoff arrays exact length per stage; no duplicates.
Lock: group update rejected if now() >= kickoff_at; playoff update rejected if now() >= tournament_start.
Champion must appear in final stage list? Enforce consistency: champion ∈ final team_ids.

## Indexes
Users: email(unique)
ScorePrediction: (match_id, user_id)
PlayoffStagePrediction: (user_id, stage)
GroupMatch: kickoff_at
LeaderboardSnapshot: generated_at(desc), rank

## State Notes
Recalculation writes ScoringResult & PlayoffScoringResult, then updates LeaderboardSnapshot.

## Edge Data Considerations
Canceled matches: record status canceled; scoring skipped.
Reschedule: update kickoff_at; predictions remain editable until new kickoff.

## Data Volume Estimate
Predictions: users * matches (~48) manageable; arrays small; snapshot per scoring event.

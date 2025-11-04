# Security Review Template (Prediction Competition)

## Scope
Authentication, predictions, scoring, admin advancement.

## Items
- [ ] Input validation (scores range, arrays length)
- [ ] Lock enforcement (no post-kickoff edits)
- [ ] Auth rate limiting (brute force mitigation)
- [ ] Password hashing (Argon2 parameters)
- [ ] Session security (signed & secure cookies in prod)
- [ ] Admin authorization (role flag + guard plug)
- [ ] Data privacy (no leaking others' predictions pre-kickoff)
- [ ] Logging (avoid PII beyond email if necessary)
- [ ] CSRF protection (forms & LiveView tokens)
- [ ] Replay prevention (lock + changeset constraints)

## Findings
(To be filled post implementation)

## Recommendations
(To be filled post review)

## Approval
- Reviewer: ____________________
- Date: ____________________
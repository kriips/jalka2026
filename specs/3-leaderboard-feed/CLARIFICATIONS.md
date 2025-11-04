## Clarification Questions

### Question 1: Conflict Resolution Flow Specifics
**Context**: [NEEDS CLARIFICATION: conflict resolution flow specifics]
**What we need to know**: How should conflicting feed vs stored scores be resolved operationally?

| Option | Answer | Implications |
|--------|--------|--------------|
| A | Admin must explicitly approve or reject each conflict before any scoring change | Ensures accuracy; may delay updates |
| B | Auto-accept feed if confidence high (e.g., provider timestamp newer) and log auto-resolution | Faster updates; minor risk of incorrect overwrite |
| C | Queue conflicts; allow bulk approve/reject actions | Operational efficiency for batches |
| Custom | Provide your own workflow | Tailor to team process |

**Your choice**: Reply Q1: A (or B/C/Custom - details)

### Question 2: Polling Interval Default
**Context**: [NEEDS CLARIFICATION: polling interval default value]
**What we need to know**: Sensible default polling frequency.

| Option | Answer | Implications |
|--------|--------|--------------|
| A | 60 seconds | Balanced timeliness vs load |
| B | 30 seconds | Faster updates; higher request volume |
| C | 120 seconds | Lower load; slower perceived responsiveness |
| Custom | Provide exact seconds | Adjust to provider limits |

**Your choice**: Reply Q2: A (or B/C/Custom - details)

### Question 3: Full vs Incremental Rescore Criteria
**Context**: [NEEDS CLARIFICATION: criteria for choosing full rescore vs targeted]
**What we need to know**: When system should run full tournament-wide rescore.

| Option | Answer | Implications |
|--------|--------|--------------|
| A | Only on playoff advancement corrections or scoring logic version change | Minimizes heavy operations |
| B | On any prior-result correction (group or playoff) | Simpler; more CPU cost |
| C | Scheduled daily + on advancement corrections | Predictable; potentially redundant |
| Custom | Provide rule set | Tailor performance vs accuracy |

**Your choice**: Reply Q3: A (or B/C/Custom - details)

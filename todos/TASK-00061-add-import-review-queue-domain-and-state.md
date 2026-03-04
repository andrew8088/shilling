---
status: ready
created: 2026-03-04
---

# Add Import Review Queue Domain And State

Context: import should not commit ambiguous rows without user review.

Acceptance criteria:
- introduce a review-queue domain model capturing parsed row, suggested account, confidence, and validation errors
- support batch approve, batch reassign, and skip semantics before final commit
- keep duplicate detection and parse-error handling compatible with the new staged flow
- ensure queue state can be regenerated deterministically for the same file and mapping

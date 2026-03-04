---
status: ready
created: 2026-03-04
---

# Add Recurring Tests And Docs

Context: schedule math and generation idempotency require strong regression coverage.

Acceptance criteria:
- add unit tests for schedule calculators across supported cadences and date edge cases
- add integration tests for generation, skip behavior, and duplicate prevention
- update docs with recurrence concepts, limitations, and user workflow
- include examples for mortgage, rent, salary, and subscription templates

---
status: ready
created: 2026-03-04
tasks:
  - TASK-00060-add-import-rule-model-and-matching-engine.md
  - TASK-00061-add-import-review-queue-domain-and-state.md
  - TASK-00062-extend-import-wizard-with-rule-suggestions-and-overrides.md
  - TASK-00063-add-import-rule-tests-and-docs.md
---

# Import Categorization Rules And Review Queue

Context: current CSV import applies one contra account to all rows, causing costly manual cleanup.

Acceptance criteria:
- import supports rule-based contra account selection using row attributes such as payee and memo
- import flow includes a review queue for unmatched or low-confidence rows before commit
- users can accept suggestions, override categories, and save new rules during review
- child tasks include tests and docs for matching behavior, precedence, and fallback handling

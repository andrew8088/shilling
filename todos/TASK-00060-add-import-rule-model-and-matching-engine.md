---
status: ready
created: 2026-03-04
---

# Add Import Rule Model And Matching Engine

Context: categorization rules need a first-class model and deterministic matching pipeline.

Acceptance criteria:
- add persisted import rule entities with fields for conditions, destination account, priority, and enabled state
- implement a matching engine that ranks and selects the best rule for each candidate row
- define conflict resolution and precedence behavior for overlapping rules
- expose matching results with confidence and explanation metadata for UI display

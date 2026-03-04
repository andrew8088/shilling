---
status: ready
created: 2026-03-04
---

# Add Import Rule Tests And Docs

Context: rule systems fail quietly without strict coverage and clear docs.

Acceptance criteria:
- add unit tests for rule matching, precedence, and no-match fallback paths
- add integration tests for staged review queue approval and final transaction creation
- update docs to define rule syntax, matching order, and review workflow
- document constraints and expected behavior for ambiguous or conflicting rules

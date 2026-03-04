---
status: ready
created: 2026-03-04
---

# Extend Budget Model With Rollover Policy

Context: carryover behavior requires explicit policy metadata in the budget domain model.

Acceptance criteria:
- add budget policy fields for rollover mode and optional carryover caps
- support non-rollover, full-rollover, and capped-rollover behavior
- preserve existing budget records with safe defaults on migration
- expose policy fields through service APIs without breaking existing callers

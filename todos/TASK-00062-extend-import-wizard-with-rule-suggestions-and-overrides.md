---
status: ready
created: 2026-03-04
---

# Extend Import Wizard With Rule Suggestions And Overrides

Context: users need a fast UI loop to validate and correct auto-categorization before import.

Acceptance criteria:
- add a review step in the import wizard that lists staged rows with suggested contra accounts
- allow per-row and bulk overrides, including save-as-rule actions from corrections
- surface confidence indicators and clear reasons when no rule matched
- commit only approved rows and report skipped/rejected totals in result summary

---
status: ready
created: 2026-03-04
---

# Add Recurring Template Model And Schedule Calculator

Context: recurring automation needs explicit template and scheduling primitives.

Acceptance criteria:
- add recurring template models with cadence, start/end dates, and posting behavior fields
- implement next-due calculation for monthly, weekly, and custom interval schedules
- handle edge cases such as month-end dates and paused templates
- expose API methods for querying due templates at a given date

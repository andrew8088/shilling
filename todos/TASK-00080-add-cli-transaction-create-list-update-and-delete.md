---
status: ready
created: 2026-03-04
---

# Add Cli Transaction Create List Update And Delete

Context: transaction management is a core workflow missing from the current CLI surface.

Acceptance criteria:
- add CLI commands for create, list/filter, update, and delete transaction operations
- support split entries and simple two-entry transactions through command arguments or input files
- include date/account/payee/amount filters for transaction listing
- support JSON output mode for all transaction commands

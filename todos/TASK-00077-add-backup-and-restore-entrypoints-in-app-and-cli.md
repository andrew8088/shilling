---
status: ready
created: 2026-03-04
---

# Add Backup And Restore Entrypoints In App And Cli

Context: portability features must be accessible to both GUI and automation users.

Acceptance criteria:
- add app-level actions for export backup and restore from file with confirmation flow
- add CLI commands for backup export and restore with non-interactive flags
- surface clear success/failure summaries including record counts and warnings
- enforce safeguards for destructive restore paths via explicit confirmation options
